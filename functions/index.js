const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.notificarCambioEstado = functions.firestore
    .document("reportes/{reporteId}")
    .onUpdate(async (change, context) => {
        const dataNueva = change.after.data();
        const dataAnterior = change.before.data();

        // Verificar si el estado cambió
        if (dataNueva.estado === dataAnterior.estado) {
            return null;
        }

        const folio = dataNueva.folio || "Sin folio";
        const nuevoEstado = dataNueva.estado;

        let userIdsToNotify = [];
        if (dataNueva.userId) {
            userIdsToNotify.push(dataNueva.userId);
        }

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

        try {
            let tokens = [];

            // Buscar tokens para todos los usuarios
            for (const uid of userIdsToNotify) {
                let fcmToken = null;
                
                // Buscar en la colección 'usuarios'
                const userDoc = await admin.firestore().collection("usuarios").doc(uid).get();
                if (userDoc.exists && userDoc.data().fcm_token) {
                    fcmToken = userDoc.data().fcm_token;
                } else {
                    // Si no está en 'usuarios', buscar en 'tokens'
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
                console.log(`No se encontraron tokens para los usuarios: ${userIdsToNotify.join(", ")}`);
                return null;
            }

            const message = {
                notification: {
                    title: "Actualización de Reporte",
                    body: `Tu reporte #${folio} pasó a: ${nuevoEstado}`,
                },
                data: {
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                    folio: folio,
                    reporteId: context.params.reporteId,
                },
                tokens: tokens,
            };

            const response = await admin.messaging().sendMulticast(message);
            console.log(`Notificaciones enviadas. Éxitos: ${response.successCount}, Fallos: ${response.failureCount}`);
            return response;
        } catch (error) {
            console.error("Error al enviar notificación:", error);
            return null;
        }
    });
