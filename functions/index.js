const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// ============================================================
// FUNCION 1: Notificar cambio de estado via push notification
// Se dispara cuando cualquier reporte cambia de estado.
// Notifica al autor original via FCM.
// ============================================================
exports.notificarCambioEstado = functions.firestore
    .document("reportes/{reporteId}")
    .onUpdate(async (change, context) => {
        const dataNueva = change.after.data();
        const dataAnterior = change.before.data();

        // Solo actuar si el estado cambio
        if (dataNueva.estado === dataAnterior.estado) {
            return null;
        }

        const folio = dataNueva.folio || "Sin folio";
        const nuevoEstado = dataNueva.estado;

        let userIdsToNotify = [];
        if (dataNueva.userId) {
            userIdsToNotify.push(dataNueva.userId);
        }

        // Compatibilidad con el campo legacy
        if (dataNueva.reportantesRelacionados && Array.isArray(dataNueva.reportantesRelacionados)) {
            dataNueva.reportantesRelacionados.forEach(id => {
                if (id && !userIdsToNotify.includes(id)) {
                    userIdsToNotify.push(id);
                }
            });
        }

        if (userIdsToNotify.length === 0) {
            console.log("No hay usuarios asociados al reporte para notificar.");
            return null;
        }

        const estadosLegibles = {
            "pendiente": "Pendiente de revision",
            "en_proceso": "En proceso de atencion",
            "atendido": "Atendido",
            "resuelto": "Resuelto",
            "cancelado": "Cancelado",
            "En Revision": "En Revision",
            "Asignado": "Asignado",
            "En Proceso": "En Proceso",
            "Resuelto": "Resuelto",
        };
        const estadoFormateado = estadosLegibles[nuevoEstado] || nuevoEstado;

        try {
            let tokens = [];

            for (const uid of userIdsToNotify) {
                let fcmToken = null;

                const userDoc = await admin.firestore().collection("usuarios").doc(uid).get();
                if (userDoc.exists && userDoc.data().fcm_token) {
                    fcmToken = userDoc.data().fcm_token;
                } else {
                    const tokenDoc = await admin.firestore().collection("tokens").doc(uid).get();
                    if (tokenDoc.exists && tokenDoc.data().token) {
                        fcmToken = tokenDoc.data().token;
                    }
                }

                if (fcmToken && !tokens.includes(fcmToken)) {
                    tokens.push(fcmToken);
                }
            }

            if (tokens.length === 0) {
                console.log(`No se encontraron tokens para: ${userIdsToNotify.join(", ")}`);
                return null;
            }

            const sendPromises = tokens.map(token => {
                const message = {
                    notification: {
                        title: "Actualizacion de Reporte",
                        body: `El estado de tu reporte #${folio} se ha actualizado a: ${estadoFormateado}`,
                    },
                    data: {
                        click_action: "FLUTTER_NOTIFICATION_CLICK",
                        folio: folio,
                        reporteId: context.params.reporteId,
                    },
                    token: token,
                };
                return admin.messaging().send(message);
            });

            const responses = await Promise.allSettled(sendPromises);

            let successCount = 0;
            let failureCount = 0;
            responses.forEach((r, index) => {
                if (r.status === "fulfilled") {
                    successCount++;
                } else {
                    failureCount++;
                    console.error(`Error enviando al token ${tokens[index]}:`, r.reason);
                }
            });

            console.log(`Notificaciones enviadas. Exitos: ${successCount}, Fallos: ${failureCount}`);
            return null;
        } catch (error) {
            console.error("Error al enviar notificacion:", error);
            return null;
        }
    });

// ============================================================
// FUNCION 2: Propagar cambio de estado a documentos duplicados
// Se dispara cuando el estado del reporte ORIGINAL cambia.
// Actualiza en batch todos los docs duplicados referenciados
// en el arreglo 'duplicadosIds' del reporte original.
// ============================================================
exports.propagarEstadoReporte = functions.firestore
    .document("reportes/{reporteId}")
    .onUpdate(async (change, context) => {
        const dataNueva = change.after.data();
        const dataAnterior = change.before.data();

        // Solo actuar si el ESTADO cambio
        if (dataNueva.estado === dataAnterior.estado) {
            return null;
        }

        // No propagar desde documentos duplicados (evitar loops infinitos)
        if (dataNueva.esDuplicado === true) {
            return null;
        }

        const duplicadosIds = dataNueva.duplicadosIds;
        if (!duplicadosIds || !Array.isArray(duplicadosIds) || duplicadosIds.length === 0) {
            return null;
        }

        const db = admin.firestore();
        const batch = db.batch();

        for (const dupId of duplicadosIds) {
            const ref = db.collection("reportes").doc(dupId);
            batch.update(ref, {
                estado: dataNueva.estado,
                historialEstados: dataNueva.historialEstados || [],
            });
        }

        await batch.commit();
        console.log(`Estado '${dataNueva.estado}' propagado a ${duplicadosIds.length} duplicados del reporte ${context.params.reporteId}`);
        return null;
    });

// ============================================================
// FUNCION 3: Verificacion de duplicados visuales via IA
// Recibe ubicacion y foto, busca reportes cercanos y usa
// GPT-4o para comparar si es el mismo problema.
// ============================================================
const axios = require("axios");

exports.verificarDuplicadoVisual = functions.https.onCall(async (data, context) => {
    // Verificar autenticacion
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Debes estar autenticado.");
    }

    const { latitud, longitud, categoria, imagenBase64 } = data;

    if (!latitud || !longitud || !categoria || !imagenBase64) {
        throw new functions.https.HttpsError("invalid-argument", "Faltan datos requeridos.");
    }

    // Configurar API Key desde el archivo .env (metodo moderno)
    const openaiKey = process.env.OPENAI_API_KEY;
    
    if (!openaiKey) {
        console.error("OPENAI_API_KEY no encontrada en process.env. Asegurate de que el archivo .env exista en la carpeta functions.");
        return { error: "Configuracion incompleta en el servidor" };
    }

    const db = admin.firestore();
    const latRange = 0.001; // Aprox 110m
    const lonRange = 0.001;

    try {
        // 1. Busqueda geografica rapida (Bounding Box)
        // Filtramos por categoria y latitud (Firestore solo permite una desigualdad por query usualmente)
        const snapshot = await db.collection("reportes")
            .where("categoria", "==", categoria)
            .where("estado", "not-in", ["resuelto", "cancelado", "Resuelto", "Cancelado"])
            .where("latitud", ">=", latitud - latRange)
            .where("latitud", "<=", latitud + latRange)
            .get();

        console.log(`Buscando duplicados visuales. Candidatos geográficos: ${snapshot.docs.length}`);

        for (const doc of snapshot.docs) {
            const candidato = doc.data();
            
            // Ignorar si es el mismo reporte (aunque onCall es antes de crear)
            if (candidato.userId === context.auth.uid && candidato.categoria === categoria) {
                // Podriamos permitir que un mismo usuario reporte lo mismo? 
                // Usualmente no, pero aqui comparamos contra otros.
            }

            // Filtrar longitud en memoria si es necesario (para precision)
            if (candidato.longitud < longitud - lonRange || candidato.longitud > longitud + lonRange) {
                continue;
            }

            // Si el candidato tiene fotos, comparamos visualmente
            if (candidato.imagenes && candidato.imagenes.length > 0) {
                const fotoCandidata = candidato.imagenes[0];

                console.log(`Comparando visualmente contra reporte: ${candidato.folio || doc.id}`);

                const response = await axios.post("https://api.openai.com/v1/chat/completions", {
                    model: "gpt-4o",
                    messages: [
                        {
                            role: "system",
                            content: `Eres un experto en gestion urbana. Tu tarea es determinar si dos fotografias muestran el MISMO incidente o problema (mismo bache, misma lampara rota, etc.). 
                            Ten en cuenta que las fotos pueden estar tomadas desde angulos diferentes o en momentos del dia distintos.
                            Responde estrictamente en formato JSON: { "esDuplicado": boolean, "confianza": number, "motivo": string }`
                        },
                        {
                            role: "user",
                            content: [
                                {
                                    type: "text",
                                    text: `¿Estas dos fotos muestran el mismo problema de '${categoria}'?`
                                },
                                {
                                    type: "image_url",
                                    image_url: { "url": imagenBase64 }
                                },
                                {
                                    type: "image_url",
                                    image_url: { "url": fotoCandidata }
                                }
                            ]
                        }
                    ],
                    response_format: { type: "json_object" },
                    max_tokens: 300
                }, {
                    headers: {
                        "Authorization": `Bearer ${openaiKey}`,
                        "Content-Type": "application/json"
                    }
                });

                const aiRes = JSON.parse(response.data.choices[0].message.content);
                console.log(`Resultado IA para ${doc.id}: Confianza ${aiRes.confianza}% - Es duplicado: ${aiRes.esDuplicado}`);

                if (aiRes.esDuplicado && aiRes.confianza > 80) {
                    return {
                        esDuplicado: true,
                        reporteOriginal: {
                            id: doc.id,
                            folio: candidato.folio,
                            categoria: candidato.categoria,
                            direccion: candidato.direccion,
                            latitud: candidato.latitud,
                            longitud: candidato.longitud,
                            estado: candidato.estado,
                            contadorDuplicados: candidato.contadorDuplicados || 0,
                            historialEstados: candidato.historialEstados || []
                        }
                    };
                }
            }
        }

        return { esDuplicado: false };

    } catch (error) {
        console.error("Error en verificarDuplicadoVisual:", error);
        return { error: "Error interno al procesar duplicados visuales" };
    }
});
