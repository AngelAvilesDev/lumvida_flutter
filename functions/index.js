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

        const userId = dataNueva.userId;
        const folio = dataNueva.folio || "Sin folio";
        const nuevoEstado = dataNueva.estado;

        if (!userId) {
            console.log("No hay userId asociado al reporte.");
            return null;
        }

        try {
            // Buscar en la colección 'usuarios'
            const userDoc = await admin.firestore().collection("usuarios").doc(userId).get();
            let fcmToken = null;

            if (userDoc.exists) {
                fcmToken = userDoc.data().fcm_token;
            }

            // Si no está en 'usuarios', buscar en 'tokens'
            if (!fcmToken) {
                const tokenDoc = await admin.firestore().collection("tokens").doc(userId).get();
                if (tokenDoc.exists) {
                    fcmToken = tokenDoc.data().token;
                }
            }

            if (!fcmToken) {
                console.log(`No se encontró token para el usuario ${userId}`);
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
                token: fcmToken,
            };

            const response = await admin.messaging().send(message);
            console.log("Notificación enviada exitosamente:", response);
            return response;
        } catch (error) {
            console.error("Error al enviar notificación:", error);
            return null;
        }
    });
