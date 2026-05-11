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
