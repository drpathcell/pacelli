#!/usr/bin/env python3
"""Generate Resources/Localizable.xcstrings (en source, es + it translations).

Keys are the English source strings exactly as they appear in code
(String(localized:) / SwiftUI literals). Interpolated strings use the
compiler's %@/%lld key forms. Strings absent from TRANSLATIONS ship
untranslated (falls back to English) — the build fails-soft, never breaks.

Regenerate after adding strings:
    python3 scripts/gen_string_catalog.py && xcodegen generate
"""
import json
import pathlib

OUT = pathlib.Path(__file__).resolve().parent.parent / "Resources" / "Localizable.xcstrings"

# en key -> (es, it)
TRANSLATIONS = {
    "A peaceful, organised home": ("Un hogar tranquilo y organizado", "Una casa serena e organizzata"),
    "Access control": ("Control de acceso", "Controllo degli accessi"),
    "Notifications": ("Notificaciones", "Notifiche"),
    "Reminders about your own tasks are created on this device and never leave it. When the other person adds a task, a notification is sent through Apple — it says only that a task was added, and the title travels with it still encrypted. Apple never has your household key, so it cannot read it, and neither can we.": (
        "Los recordatorios de tus propias tareas se crean en este dispositivo y nunca salen de él. Cuando la otra persona añade una tarea, se envía una notificación a través de Apple: solo dice que se añadió una tarea, y el título viaja con ella todavía cifrado. Apple nunca tiene la clave de tu hogar, así que no puede leerlo, y nosotros tampoco.",
        "I promemoria delle tue attività sono creati su questo dispositivo e non lo lasciano mai. Quando l'altra persona aggiunge un'attività, viene inviata una notifica tramite Apple: dice solo che un'attività è stata aggiunta, e il titolo viaggia con essa ancora cifrato. Apple non ha mai la chiave della tua casa, quindi non può leggerlo, e nemmeno noi."),
    "Feedback you send us is encrypted on this device so that only the Pacelli developer can read it — not with your household key, which never leaves your devices.": (
        "Los comentarios que nos envías se cifran en este dispositivo para que solo el desarrollador de Pacelli pueda leerlos, no con la clave de tu hogar, que nunca sale de tus dispositivos.",
        "I feedback che ci invii sono cifrati su questo dispositivo in modo che solo lo sviluppatore di Pacelli possa leggerli, non con la chiave della tua casa, che non lascia mai i tuoi dispositivi."),
    "Account": ("Cuenta", "Account"),
    "Account deletion was cancelled. Your data has already been wiped; sign-in state is unchanged.": (
        "Se canceló la eliminación de la cuenta. Tus datos ya se han borrado; la sesión no ha cambiado.",
        "L'eliminazione dell'account è stata annullata. I tuoi dati sono già stati cancellati; l'accesso resta invariato."),
    "Add a checklist item": ("Añadir un elemento", "Aggiungi un elemento"),
    "Add a subtask": ("Añadir una subtarea", "Aggiungi una sottoattività"),
    "Add a weekly plan below.": ("Añade un plan semanal abajo.", "Aggiungi un piano settimanale qui sotto."),
    "Add an item": ("Añadir un elemento", "Aggiungi un elemento"),
    "Add category": ("Añadir categoría", "Aggiungi categoria"),
    "Add entry": ("Añadir entrada", "Aggiungi voce"),
    "Add your first checklist below.": ("Añade tu primera lista abajo.", "Aggiungi la tua prima lista qui sotto."),
    "Add your first task below.": ("Añade tu primera tarea abajo.", "Aggiungi la tua prima attività qui sotto."),
    "Appearance": ("Apariencia", "Aspetto"),
    "Apple didn't return a valid credential. Please try again.": (
        "Apple no devolvió una credencial válida. Inténtalo de nuevo.",
        "Apple non ha restituito credenziali valide. Riprova."),
    "Before you burn": ("Antes de quemar", "Prima di eliminare"),
    "Bug report": ("Informe de error", "Segnalazione di errore"),
    "Burn all data": ("Quemar todos los datos", "Elimina tutti i dati"),
    "Burn all data and delete my account": ("Quemar todos los datos y eliminar mi cuenta", "Elimina tutti i dati e il mio account"),
    "Burning… don't close the app": ("Quemando… no cierres la app", "Eliminazione in corso… non chiudere l'app"),
    "Cancel": ("Cancelar", "Annulla"),
    "Categories": ("Categorías", "Categorie"),
    "Category": ("Categoría", "Categoria"),
    "Category icons and colours": ("Iconos y colores de categorías", "Icone e colori delle categorie"),
    "Category names": ("Nombres de categorías", "Nomi delle categorie"),
    "Checklist": ("Lista", "Lista"),
    "Checklist item": ("Elemento de lista", "Elemento della lista"),
    "Checklist titles and item titles": ("Títulos de listas y de sus elementos", "Titoli delle liste e dei loro elementi"),
    "Checklists": ("Listas", "Liste"),
    "Colours": ("Colores", "Colori"),
    "Completion status and priority": ("Estado de finalización y prioridad", "Stato di completamento e priorità"),
    "Confirm": ("Confirmar", "Conferma"),
    "Confirm password": ("Confirmar contraseña", "Conferma password"),
    "Confirm your identity to finish deleting your account.": (
        "Confirma tu identidad para terminar de eliminar tu cuenta.",
        "Conferma la tua identità per completare l'eliminazione dell'account."),
    "Confirm your password": ("Confirma tu contraseña", "Conferma la tua password"),
    "Content": ("Contenido", "Contenuto"),
    "Continue as guest": ("Continuar como invitado", "Continua come ospite"),
    "Continue with Google": ("Continuar con Google", "Continua con Google"),
    "Couldn't add the category.": ("No se pudo añadir la categoría.", "Impossibile aggiungere la categoria."),
    "Couldn't add the checklist.": ("No se pudo añadir la lista.", "Impossibile aggiungere la lista."),
    "Couldn't add the entry.": ("No se pudo añadir la entrada.", "Impossibile aggiungere la voce."),
    "Couldn't add the item.": ("No se pudo añadir el elemento.", "Impossibile aggiungere l'elemento."),
    "Couldn't add the plan.": ("No se pudo añadir el plan.", "Impossibile aggiungere il piano."),
    "Couldn't add the subtask.": ("No se pudo añadir la subtarea.", "Impossibile aggiungere la sottoattività."),
    "Couldn't add the task.": ("No se pudo añadir la tarea.", "Impossibile aggiungere l'attività."),
    "Couldn't delete the category.": ("No se pudo eliminar la categoría.", "Impossibile eliminare la categoria."),
    "Couldn't delete the checklist.": ("No se pudo eliminar la lista.", "Impossibile eliminare la lista."),
    "Couldn't delete the entry.": ("No se pudo eliminar la entrada.", "Impossibile eliminare la voce."),
    "Couldn't delete the item.": ("No se pudo eliminar el elemento.", "Impossibile eliminare l'elemento."),
    "Couldn't delete the plan.": ("No se pudo eliminar el plan.", "Impossibile eliminare il piano."),
    "Couldn't delete the subtask.": ("No se pudo eliminar la subtarea.", "Impossibile eliminare la sottoattività."),
    "Couldn't delete the task.": ("No se pudo eliminar la tarea.", "Impossibile eliminare l'attività."),
    "Couldn't load checklists.": ("No se pudieron cargar las listas.", "Impossibile caricare le liste."),
    "Couldn't load household members.": ("No se pudieron cargar los miembros del hogar.", "Impossibile caricare i membri della casa."),
    "Couldn't load plans.": ("No se pudieron cargar los planes.", "Impossibile caricare i piani."),
    "Couldn't load task details.": ("No se pudieron cargar los detalles de la tarea.", "Impossibile caricare i dettagli dell'attività."),
    "Couldn't load tasks.": ("No se pudieron cargar las tareas.", "Impossibile caricare le attività."),
    "Couldn't load the manual.": ("No se pudo cargar el manual.", "Impossibile caricare il manuale."),
    "Couldn't move the item to tasks.": ("No se pudo convertir el elemento en tarea.", "Impossibile trasformare l'elemento in attività."),
    "Couldn't open Google Sign-In right now. Please try again.": (
        "No se pudo abrir el inicio de sesión de Google. Inténtalo de nuevo.",
        "Impossibile aprire l'accesso Google. Riprova."),
    "Couldn't remove the member.": ("No se pudo quitar al miembro.", "Impossibile rimuovere il membro."),
    "Couldn't revoke the invite.": ("No se pudo revocar la invitación.", "Impossibile revocare l'invito."),
    "Couldn't save the entry.": ("No se pudo guardar la entrada.", "Impossibile salvare la voce."),
    "Couldn't save your changes.": ("No se pudieron guardar tus cambios.", "Impossibile salvare le modifiche."),
    "Couldn't send the invite.": ("No se pudo enviar la invitación.", "Impossibile inviare l'invito."),
    "Couldn't send your feedback.": ("No se pudo enviar tu opinión.", "Impossibile inviare il tuo feedback."),
    "Couldn't start guest mode. Please check your connection and try again.": (
        "No se pudo iniciar el modo invitado. Comprueba tu conexión e inténtalo de nuevo.",
        "Impossibile avviare la modalità ospite. Controlla la connessione e riprova."),
    "Couldn't update the item.": ("No se pudo actualizar el elemento.", "Impossibile aggiornare l'elemento."),
    "Couldn't update the plan.": ("No se pudo actualizar el plan.", "Impossibile aggiornare il piano."),
    "Couldn't update the subtask.": ("No se pudo actualizar la subtarea.", "Impossibile aggiornare la sottoattività."),
    "Couldn't update the task.": ("No se pudo actualizar la tarea.", "Impossibile aggiornare l'attività."),
    "Create account": ("Crear cuenta", "Crea account"),
    "Danger zone": ("Zona de peligro", "Zona pericolosa"),
    "Dark": ("Oscuro", "Scuro"),
    "Dates and times": ("Fechas y horas", "Date e orari"),
    "Day": ("Día", "Giorno"),
    "Default category": ("Categoría predeterminada", "Categoria predefinita"),
    "Delete": ("Eliminar", "Elimina"),
    "Delete checklist": ("Eliminar lista", "Elimina lista"),
    "Delete checklist and items": ("Eliminar lista y elementos", "Elimina lista ed elementi"),
    "Delete entry": ("Eliminar entrada", "Elimina voce"),
    "Delete everything?": ("¿Eliminar todo?", "Eliminare tutto?"),
    "Delete plan": ("Eliminar plan", "Elimina piano"),
    "Delete plan, entries and checklist": ("Eliminar plan, entradas y lista", "Elimina piano, voci e lista"),
    "Delete task": ("Eliminar tarea", "Elimina attività"),
    "Delete task and subtasks": ("Eliminar tarea y subtareas", "Elimina attività e sottoattività"),
    "Delete this checklist?": ("¿Eliminar esta lista?", "Eliminare questa lista?"),
    "Delete this entry?": ("¿Eliminar esta entrada?", "Eliminare questa voce?"),
    "Delete this plan?": ("¿Eliminar este plan?", "Eliminare questo piano?"),
    "Delete this task?": ("¿Eliminar esta tarea?", "Eliminare questa attività?"),
    "Deleting your account needs a recent sign-in.": (
        "Eliminar tu cuenta requiere un inicio de sesión reciente.",
        "Per eliminare l'account serve un accesso recente."),
    "Deleting your account needs a recent sign-in. Please confirm your identity.": (
        "Eliminar tu cuenta requiere un inicio de sesión reciente. Confirma tu identidad.",
        "Per eliminare l'account serve un accesso recente. Conferma la tua identità."),
    "Details": ("Detalles", "Dettagli"),
    "Done": ("Hecho", "Fatto"),
    "Due date": ("Fecha límite", "Scadenza"),
    "Email": ("Correo electrónico", "Email"),
    "Email address": ("Dirección de correo", "Indirizzo email"),
    "Encrypted before upload": ("Cifrado antes de subir", "Cifrato prima del caricamento"),
    "Entry": ("Entrada", "Voce"),
    "Entry title": ("Título de la entrada", "Titolo della voce"),
    "Every record is tied to your household. Server rules only allow access to signed-in members of that household — including for guest accounts.": (
        "Cada registro está vinculado a tu hogar. Las reglas del servidor solo permiten el acceso a miembros del hogar con sesión iniciada, incluidas las cuentas de invitado.",
        "Ogni record è legato alla tua casa. Le regole del server consentono l'accesso solo ai membri autenticati di quella casa, inclusi gli account ospite."),
    "Everyone in your household loses this data — tell them first.": (
        "Todos en tu hogar perderán estos datos — avísales primero.",
        "Tutti nella tua casa perderanno questi dati — avvisali prima."),
    "Everything has been deleted.": ("Todo se ha eliminado.", "Tutto è stato eliminato."),
    "Feature request": ("Petición de función", "Richiesta di funzionalità"),
    "Files saved to Google Drive are NOT deleted — remove those in Drive yourself.": (
        "Los archivos guardados en Google Drive NO se eliminan — bórralos tú mismo en Drive.",
        "I file salvati su Google Drive NON vengono eliminati — rimuovili tu stesso in Drive."),
    "Finalised": ("Finalizado", "Finalizzato"),
    "General": ("General", "Generale"),
    "Google Sign-In isn't configured. Please try another method.": (
        "El inicio de sesión de Google no está configurado. Prueba otro método.",
        "L'accesso Google non è configurato. Prova un altro metodo."),
    "Google didn't return a valid credential. Please try again.": (
        "Google no devolvió una credencial válida. Inténtalo de nuevo.",
        "Google non ha restituito credenziali valide. Riprova."),
    "High": ("Alta", "Alta"),
    "Household": ("Hogar", "Casa"),
    "Household manual": ("Manual del hogar", "Manuale della casa"),
    "Household name": ("Nombre del hogar", "Nome della casa"),
    "How's Pacelli?": ("¿Qué tal Pacelli?", "Come va Pacelli?"),
    "Invite sent. %@ will join when they sign in with that email.": (
        "Invitación enviada. %@ se unirá cuando inicie sesión con ese correo.",
        "Invito inviato. %@ si unirà quando accederà con quell'email."),
    "Invite someone": ("Invitar a alguien", "Invita qualcuno"),
    "Item quantities": ("Cantidades de los elementos", "Quantità degli elementi"),
    "Items": ("Elementos", "Elementi"),
    "Keep how-tos and household notes here — bin schedules, appliance quirks, wifi details.": (
        "Guarda aquí guías y notas del hogar: horarios de basura, manías de los electrodomésticos, datos del wifi.",
        "Conserva qui guide e note della casa: orari dei rifiuti, particolarità degli elettrodomestici, dati del wifi."),
    "Light": ("Claro", "Chiaro"),
    "Loading your home…": ("Cargando tu hogar…", "Caricamento della tua casa…"),
    "Low": ("Baja", "Bassa"),
    "Make task": ("Crear tarea", "Crea attività"),
    "Manage categories": ("Gestionar categorías", "Gestisci categorie"),
    "Manual": ("Manual", "Manuale"),
    "Medium": ("Media", "Media"),
    "Member": ("Miembro", "Membro"),
    "Members": ("Miembros", "Membri"),
    "Members & invites": ("Miembros e invitaciones", "Membri e inviti"),
    "My Household": ("Mi hogar", "La mia casa"),
    "Name": ("Nombre", "Nome"),
    "New category": ("Nueva categoría", "Nuova categoria"),
    "New checklist": ("Nueva lista", "Nuova lista"),
    "New entry": ("Nueva entrada", "Nuova voce"),
    "New task": ("Nueva tarea", "Nuova attività"),
    "New weekly plan": ("Nuevo plan semanal", "Nuovo piano settimanale"),
    "No checklists yet": ("Aún no hay listas", "Ancora nessuna lista"),
    "No email on this account.": ("Esta cuenta no tiene correo.", "Questo account non ha un'email."),
    "No entries": ("Sin entradas", "Nessuna voce"),
    "No manual entries yet": ("Aún no hay entradas en el manual", "Ancora nessuna voce nel manuale"),
    "No plans yet": ("Aún no hay planes", "Ancora nessun piano"),
    "No tasks yet": ("Aún no hay tareas", "Ancora nessuna attività"),
    "None": ("Ninguna", "Nessuna"),
    "Not encrypted": ("Sin cifrar", "Non cifrato"),
    "Notes": ("Notas", "Note"),
    "OK": ("OK", "OK"),
    "Password": ("Contraseña", "Password"),
    "Pending invites": ("Invitaciones pendientes", "Inviti in sospeso"),
    "Permanently deletes your household data and your account.": (
        "Elimina permanentemente los datos de tu hogar y tu cuenta.",
        "Elimina definitivamente i dati della tua casa e il tuo account."),
    "Pinned": ("Fijado", "In evidenza"),
    "Plan": ("Plan", "Piano"),
    "Plan entry": ("Entrada del plan", "Voce del piano"),
    "Plan titles, entry titles, labels and descriptions": (
        "Títulos de planes, títulos de entradas, etiquetas y descripciones",
        "Titoli dei piani, titoli delle voci, etichette e descrizioni"),
    "Plans": ("Planes", "Piani"),
    "Priority": ("Prioridad", "Priorità"),
    "Privacy": ("Privacidad", "Privacy"),
    "Privacy & encryption": ("Privacidad y cifrado", "Privacy e cifratura"),
    "Progress": ("Progreso", "Avanzamento"),
    "Qty": ("Cant.", "Qtà"),
    "Remove": ("Quitar", "Rimuovi"),
    "Retry": ("Reintentar", "Riprova"),
    "Revoke": ("Revocar", "Revoca"),
    "Save": ("Guardar", "Salva"),
    "Search": ("Buscar", "Cerca"),
    "Search everything": ("Buscar en todo", "Cerca ovunque"),
    "Search your household": ("Busca en tu hogar", "Cerca nella tua casa"),
    "Send feedback": ("Enviar opinión", "Invia feedback"),
    "Setting things up…": ("Preparando todo…", "Preparazione in corso…"),
    "Settings": ("Ajustes", "Impostazioni"),
    "Sign in": ("Iniciar sesión", "Accedi"),
    "Sign out": ("Cerrar sesión", "Esci"),
    "Signed in": ("Sesión iniciada", "Accesso effettuato"),
    "Signed in, but we couldn't load your home. Please try again.": (
        "Sesión iniciada, pero no pudimos cargar tu hogar. Inténtalo de nuevo.",
        "Accesso effettuato, ma non siamo riusciti a caricare la tua casa. Riprova."),
    "Something went wrong": ("Algo salió mal", "Qualcosa è andato storto"),
    "Sort order and record identifiers": ("Orden y identificadores de registros", "Ordinamento e identificatori dei record"),
    "Subtask": ("Subtarea", "Sottoattività"),
    "Subtask titles": ("Títulos de subtareas", "Titoli delle sottoattività"),
    "Subtasks": ("Subtareas", "Sottoattività"),
    "System": ("Sistema", "Sistema"),
    "Task": ("Tarea", "Attività"),
    "Task titles and notes": ("Títulos y notas de tareas", "Titoli e note delle attività"),
    "Tasks": ("Tareas", "Attività"),
    "Tasks, checklists, plans and the manual — everything is searched after decryption, on this device.": (
        "Tareas, listas, planes y el manual — todo se busca tras descifrarse, en este dispositivo.",
        "Attività, liste, piani e il manuale — tutto viene cercato dopo la decifratura, su questo dispositivo."),
    "Tell us more…": ("Cuéntanos más…", "Dicci di più…"),
    "Thank you!": ("¡Gracias!", "Grazie!"),
    "That took too long. Check your connection and try again.": (
        "Tardó demasiado. Comprueba tu conexión e inténtalo de nuevo.",
        "Ci è voluto troppo tempo. Controlla la connessione e riprova."),
    "Theme": ("Tema", "Tema"),
    "These fields stay readable so the app can query, sort and enforce access rules on the server. They contain no free-text content.": (
        "Estos campos permanecen legibles para que la app pueda consultar, ordenar y aplicar reglas de acceso en el servidor. No contienen texto libre.",
        "Questi campi restano leggibili così l'app può interrogare, ordinare e applicare le regole di accesso sul server. Non contengono testo libero."),
    "They join when they sign in to Pacelli with this email. The household key is shared securely as part of the invite.": (
        "Se unirán al iniciar sesión en Pacelli con este correo. La clave del hogar se comparte de forma segura como parte de la invitación.",
        "Si uniranno accedendo a Pacelli con questa email. La chiave della casa viene condivisa in modo sicuro come parte dell'invito."),
    "This also deletes its items. This can't be undone.": (
        "También se eliminan sus elementos. No se puede deshacer.",
        "Verranno eliminati anche i suoi elementi. Non si può annullare."),
    "This also deletes its subtasks. This can't be undone.": (
        "También se eliminan sus subtareas. No se puede deshacer.",
        "Verranno eliminate anche le sue sottoattività. Non si può annullare."),
    "This can't be undone.": ("No se puede deshacer.", "Non si può annullare."),
    "This cannot be undone.": ("Esto no se puede deshacer.", "Questa operazione non si può annullare."),
    "This permanently deletes your tasks, checklists, plans, categories, household and account.": (
        "Esto elimina permanentemente tus tareas, listas, planes, categorías, hogar y cuenta.",
        "Questo elimina definitivamente attività, liste, piani, categorie, casa e account."),
    "Title": ("Título", "Titolo"),
    "Type": ("Tipo", "Tipo"),
    "Urgent": ("Urgente", "Urgente"),
    "Using Pacelli as a guest": ("Usando Pacelli como invitado", "Stai usando Pacelli come ospite"),
    "We couldn't restore your previous session, so we've reset it. Continue as guest below.": (
        "No pudimos restaurar tu sesión anterior, así que la hemos restablecido. Continúa como invitado abajo.",
        "Non siamo riusciti a ripristinare la sessione precedente, quindi l'abbiamo azzerata. Continua come ospite qui sotto."),
    "Write it down…": ("Escríbelo…", "Scrivilo…"),
    "You": ("Tú", "Tu"),
    "You're not signed in.": ("No has iniciado sesión.", "Non hai effettuato l'accesso."),
    "Your content is encrypted on this device with AES-256 before it is uploaded. Each household has its own random key; that key is wrapped with a key derived from your account and stored so only household members can unwrap it. Your keys are cached in the device Keychain and never leave your devices unencrypted.": (
        "Tu contenido se cifra en este dispositivo con AES-256 antes de subirse. Cada hogar tiene su propia clave aleatoria; esa clave se envuelve con una clave derivada de tu cuenta y se guarda de modo que solo los miembros del hogar puedan abrirla. Tus claves se guardan en el llavero del dispositivo y nunca salen de tus dispositivos sin cifrar.",
        "I tuoi contenuti vengono cifrati su questo dispositivo con AES-256 prima del caricamento. Ogni casa ha la propria chiave casuale; quella chiave è avvolta con una chiave derivata dal tuo account e salvata in modo che solo i membri della casa possano aprirla. Le tue chiavi restano nel portachiavi del dispositivo e non lasciano mai i tuoi dispositivi in chiaro."),
    "Your data lives safely in this household. Create an account to keep it if you switch devices.": (
        "Tus datos viven seguros en este hogar. Crea una cuenta para conservarlos si cambias de dispositivo.",
        "I tuoi dati sono al sicuro in questa casa. Crea un account per conservarli se cambi dispositivo."),
    "Your display name": ("Tu nombre visible", "Il tuo nome visualizzato"),
    "Your feedback has been sent.": ("Tu opinión se ha enviado.", "Il tuo feedback è stato inviato."),
    "Your household and tasks come with you — nothing is lost.": (
        "Tu hogar y tus tareas van contigo — no se pierde nada.",
        "La tua casa e le tue attività vengono con te — non si perde nulla."),
    "Your household data, encryption keys and account will be permanently deleted. This can't be undone.": (
        "Los datos de tu hogar, las claves de cifrado y tu cuenta se eliminarán permanentemente. No se puede deshacer.",
        "I dati della tua casa, le chiavi di cifratura e il tuo account saranno eliminati definitivamente. Non si può annullare."),
    "Your message is encrypted on this device so that only the Pacelli developer can read it. Nobody else, including anyone who could reach the database, can.": (
        "Tu mensaje se cifra en este dispositivo para que solo el desarrollador de Pacelli pueda leerlo. Nadie más, ni siquiera quien pudiera acceder a la base de datos, puede hacerlo.",
        "Il tuo messaggio viene cifrato su questo dispositivo in modo che solo lo sviluppatore di Pacelli possa leggerlo. Nessun altro, nemmeno chi potesse accedere al database, può farlo."),
    "Email (only if you'd like a reply)": (
        "Correo electrónico (solo si quieres respuesta)",
        "Email (solo se desideri una risposta)"),
    "Optional. Leave it blank to stay anonymous.": (
        "Opcional. Déjalo en blanco para permanecer anónimo.",
        "Facoltativo. Lascialo vuoto per restare anonimo."),
    "Deletion verification found %lld surviving record(s). Nothing has been hidden — please retry.": (
        "La verificación encontró %lld registro(s) sin eliminar. No se ha ocultado nada — reinténtalo.",
        "La verifica ha trovato %lld record non eliminati. Nulla è stato nascosto — riprova."),
    "😊 Good": ("😊 Bien", "😊 Bene"),
    "😐 Okay": ("😐 Normal", "😐 Così così"),
    "🙁 Bad": ("🙁 Mal", "🙁 Male"),
    # 1.1 — household rename + data export + generic theme names:
    "Lavender": ("Lavanda", "Lavanda"),
    "Ocean": ("Océano", "Oceano"),
    "Household name": ("Nombre del hogar", "Nome della casa"),
    "Couldn't rename the household.": (
        "No se pudo renombrar el hogar.", "Impossibile rinominare la casa."),
    "Your data": ("Tus datos", "I tuoi dati"),
    "Export data": ("Exportar datos", "Esporta dati"),
    "Export": ("Exportar", "Esporta"),
    "Save a backup of everything in your household as a JSON file.": (
        "Guarda una copia de seguridad de todo tu hogar en un archivo JSON.",
        "Salva un backup di tutto ciò che c'è nella tua casa in un file JSON."),
    "Export a readable copy?": (
        "¿Exportar una copia legible?", "Esportare una copia leggibile?"),
    "The exported file contains your household data in readable form — it is not encrypted. Keep it somewhere safe.": (
        "El archivo exportado contiene los datos de tu hogar en forma legible — no está cifrado. Guárdalo en un lugar seguro.",
        "Il file esportato contiene i dati della tua casa in forma leggibile — non è cifrato. Conservalo in un luogo sicuro."),
    "Couldn't export your data. Please check your connection and try again.": (
        "No se pudieron exportar tus datos. Comprueba tu conexión e inténtalo de nuevo.",
        "Impossibile esportare i tuoi dati. Controlla la connessione e riprova."),
    # ── Join codes (1.2.0) ────────────────────────────────────────────
    "I have a join code": ("Tengo un código de acceso", "Ho un codice di accesso"),
    "Join a household": ("Unirse a un hogar", "Unisciti a una casa"),
    "Join another household": ("Unirse a otro hogar", "Unisciti a un'altra casa"),
    "Join household": ("Unirse al hogar", "Unisciti alla casa"),
    "Join code": ("Código de acceso", "Codice di accesso"),
    "Join": ("Unirse", "Unisciti"),
    "Joining…": ("Uniéndose…", "Accesso in corso…"),
    "Code": ("Código", "Codice"),
    "Create a join code": ("Crear un código de acceso", "Crea un codice di accesso"),
    "Generate a new code": ("Generar un código nuevo", "Genera un nuovo codice"),
    "That code expired — create a new one": (
        "Ese código caducó — crea uno nuevo",
        "Quel codice è scaduto — creane uno nuovo"),
    "Turn off the code": ("Desactivar el código", "Disattiva il codice"),
    "Expires today": ("Caduca hoy", "Scade oggi"),
    "Expires in %lld days": ("Caduca en %lld días", "Scade tra %lld giorni"),
    "Read this code out or share it — whoever types it joins straight away, whatever they sign in with. Use this if they sign in with Apple and hide their email, because then nobody can invite that address. Codes last 7 days.": (
        "Lee este código en voz alta o compártelo — quien lo escriba entra al instante, sea cual sea su forma de iniciar sesión. Úsalo si inician sesión con Apple y ocultan su correo, porque entonces nadie puede invitar esa dirección. Los códigos duran 7 días.",
        "Leggi questo codice ad alta voce o condividilo — chi lo digita entra subito, qualunque sia il suo metodo di accesso. Usalo se accedono con Apple nascondendo l'email, perché in quel caso nessuno può invitare quell'indirizzo. I codici durano 7 giorni."),
    "Got a code from someone else? Enter it here to switch to their household.": (
        "¿Alguien te dio un código? Escríbelo aquí para cambiarte a su hogar.",
        "Hai ricevuto un codice? Inseriscilo qui per passare alla loro casa."),
    "Ask someone already in the household to open Household → Join code. You don't need an account — you can add one later.": (
        "Pide a alguien que ya esté en el hogar que abra Hogar → Código de acceso. No necesitas una cuenta — puedes crearla más tarde.",
        "Chiedi a chi è già nella casa di aprire Casa → Codice di accesso. Non serve un account — puoi crearlo più tardi."),
    "Join our Pacelli household with this code: %@": (
        "Únete a nuestro hogar en Pacelli con este código: %@",
        "Unisciti alla nostra casa su Pacelli con questo codice: %@"),
    "Couldn't create a join code.": (
        "No se pudo crear el código de acceso.", "Impossibile creare il codice di accesso."),
    "Couldn't turn off the join code.": (
        "No se pudo desactivar el código de acceso.",
        "Impossibile disattivare il codice di accesso."),
    "Couldn't join with that code.": (
        "No se pudo unir con ese código.", "Impossibile unirsi con quel codice."),
    "Couldn't join with that code. Check it and try again.": (
        "No se pudo unir con ese código. Compruébalo e inténtalo de nuevo.",
        "Impossibile unirsi con quel codice. Controllalo e riprova."),
    "That code isn't valid any more. Ask for a new one — codes expire after 7 days.": (
        "Ese código ya no es válido. Pide uno nuevo — los códigos caducan a los 7 días.",
        "Quel codice non è più valido. Chiedine uno nuovo — i codici scadono dopo 7 giorni."),
    "That code didn't unlock the household. Ask for a freshly generated one.": (
        "Ese código no desbloqueó el hogar. Pide uno recién generado.",
        "Quel codice non ha sbloccato la casa. Chiedine uno appena generato."),
    "You're already a member of that household.": (
        "Ya eres miembro de ese hogar.", "Fai già parte di quella casa."),
    "You joined, but we couldn't open the household. Try reopening Pacelli.": (
        "Te uniste, pero no pudimos abrir el hogar. Prueba a reabrir Pacelli.",
        "Ti sei unito, ma non siamo riusciti ad aprire la casa. Prova a riaprire Pacelli."),
    "There's an invite waiting for you, but we couldn't join that household. Ask whoever invited you for a join code instead.": (
        "Hay una invitación esperándote, pero no pudimos unirte a ese hogar. Pide a quien te invitó un código de acceso.",
        "C'è un invito che ti aspetta, ma non siamo riusciti a unirti a quella casa. Chiedi a chi ti ha invitato un codice di accesso."),
    "You've been invited to a household, but we couldn't join it. Ask whoever invited you for a join code and use “I have a join code” below.": (
        "Te han invitado a un hogar, pero no pudimos unirte. Pide a quien te invitó un código de acceso y usa «Tengo un código de acceso» abajo.",
        "Sei stato invitato in una casa, ma non siamo riusciti a unirti. Chiedi a chi ti ha invitato un codice di accesso e usa «Ho un codice di accesso» qui sotto."),
    # Sample code shown as a field placeholder — identical in every locale.
    "K7QP-4M2X": ("K7QP-4M2X", "K7QP-4M2X"),
    # ── Reminders (1.3.0) ─────────────────────────────────────────────
    "Reminders": ("Recordatorios", "Promemoria"),
    "Task reminders": ("Recordatorios de tareas", "Promemoria attività"),
    "Remind me at": ("Recordarme a las", "Ricordamelo alle"),
    "Also remind me the day before": (
        "Recordármelo también el día anterior", "Ricordamelo anche il giorno prima"),
    "Reminder at a set time": ("Recordatorio a una hora concreta", "Promemoria a un'ora precisa"),
    "Due": ("Vence", "Scadenza"),
    "Due today": ("Vence hoy", "Scade oggi"),
    "Due tomorrow": ("Vence mañana", "Scade domani"),
    "Tasks with a due date remind you at this time on the day. A task can set its own time. Reminders are created on this device and never leave it. Task alerts from the other person are sent through Apple, and what they say is encrypted.": (
        "Las tareas con fecha te avisan a esta hora ese día. Una tarea puede tener su propia hora. Los recordatorios se crean en este dispositivo y nunca salen de él. Los avisos de tareas de la otra persona se envían a través de Apple, y su contenido va cifrado.",
        "Le attività con una data ti avvisano a quest'ora quel giorno. Un'attività può avere un orario suo. I promemoria sono creati su questo dispositivo e non lo lasciano mai. Gli avvisi di attività dell'altra persona passano da Apple e il loro contenuto è cifrato."),
    "Tell me when someone adds a task": (
        "Avisarme cuando alguien añada una tarea",
        "Avvisami quando qualcuno aggiunge un'attività"),
    "Reminds you at %@, your default time.": (
        "Te avisa a las %@, tu hora predeterminada.",
        "Ti avvisa alle %@, il tuo orario predefinito."),
    "Turn on reminders in Settings to be notified.": (
        "Activa los recordatorios en Ajustes para recibir avisos.",
        "Attiva i promemoria nelle Impostazioni per ricevere avvisi."),
    "Notifications are off": ("Las notificaciones están desactivadas", "Le notifiche sono disattivate"),
    "Pacelli can't send reminders until you allow notifications in iOS Settings.": (
        "Pacelli no puede enviar recordatorios hasta que permitas las notificaciones en los Ajustes de iOS.",
        "Pacelli non può inviare promemoria finché non consenti le notifiche nelle Impostazioni di iOS."),
    "Open Settings": ("Abrir Ajustes", "Apri Impostazioni"),
    "Not now": ("Ahora no", "Non ora"),
    # Brand names / identical across locales:
    "Pacelli": ("Pacelli", "Pacelli"),
}

catalog = {"sourceLanguage": "en", "strings": {}, "version": "1.0"}
for key, (es, it) in sorted(TRANSLATIONS.items()):
    entry = {"localizations": {}}
    if es != key:
        entry["localizations"]["es"] = {"stringUnit": {"state": "translated", "value": es}}
    if it != key:
        entry["localizations"]["it"] = {"stringUnit": {"state": "translated", "value": it}}
    if not entry["localizations"]:
        entry = {"shouldTranslate": False}
    catalog["strings"][key] = entry

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
print(f"Wrote {OUT} with {len(TRANSLATIONS)} strings")
