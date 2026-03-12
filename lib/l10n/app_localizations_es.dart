// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonAdd => 'Añadir';

  @override
  String get commonCreate => 'Crear';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonChange => 'Cambiar';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonToday => 'Hoy';

  @override
  String get commonTomorrow => 'Mañana';

  @override
  String get commonUnassigned => 'Sin asignar';

  @override
  String get commonUnknown => 'Desconocido';

  @override
  String get commonUntitled => 'Sin título';

  @override
  String get commonShared => 'Compartida';

  @override
  String commonError(String error) {
    return 'Error: $error';
  }

  @override
  String get authWelcomeBack => 'Bienvenido de nuevo';

  @override
  String get authSignInToHousehold => 'Inicia sesión en tu hogar';

  @override
  String get authOrSignInWithEmail => 'o inicia sesión con email';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Contraseña';

  @override
  String get authEnterEmail => 'Por favor, introduce tu email';

  @override
  String get authEnterValidEmail => 'Por favor, introduce un email válido';

  @override
  String get authEnterPassword => 'Por favor, introduce tu contraseña';

  @override
  String get authPasswordMinLength =>
      'La contraseña debe tener al menos 6 caracteres';

  @override
  String get authEnterEmailFirst => 'Introduce tu email primero';

  @override
  String get authPasswordResetSent =>
      '¡Email de restablecimiento enviado! Revisa tu bandeja de entrada.';

  @override
  String get authForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get authSignIn => 'Iniciar Sesión';

  @override
  String get authNoAccount => '¿No tienes cuenta? ';

  @override
  String get authSignUp => 'Regístrate';

  @override
  String get authContinueWithGoogle => 'Continuar con Google';

  @override
  String get authGoogleSignInFailed =>
      'El inicio de sesión con Google falló. Inténtalo de nuevo.';

  @override
  String get authLoginFailed =>
      'Inicio de sesión fallido. Verifica tu email y contraseña.';

  @override
  String get authCreateAccount => 'Crear cuenta';

  @override
  String get authStartOrganising => 'Empieza a organizar tu hogar con amor';

  @override
  String get authOrSignUpWithEmail => 'o regístrate con email';

  @override
  String get authFullName => 'Nombre completo';

  @override
  String get authConfirmPassword => 'Confirmar contraseña';

  @override
  String get authEnterName => 'Por favor, introduce tu nombre';

  @override
  String get authEnterAPassword => 'Por favor, introduce una contraseña';

  @override
  String get authPasswordMin8 =>
      'La contraseña debe tener al menos 8 caracteres';

  @override
  String get authPasswordsDoNotMatch => 'Las contraseñas no coinciden';

  @override
  String get authCreateAccountButton => 'Crear Cuenta';

  @override
  String get authAlreadyHaveAccount => '¿Ya tienes cuenta? ';

  @override
  String get authAccountCreated => '¡Cuenta creada! Bienvenido a Pacelli.';

  @override
  String get authSignupFailed => 'Registro fallido. Inténtalo de nuevo.';

  @override
  String get authAppName => 'Pacelli';

  @override
  String get authTagline => 'Un hogar tranquilo, organizado con amor.';

  @override
  String homeHelloGreeting(String userName) {
    return 'Hola, $userName';
  }

  @override
  String get homeLoadingHousehold => 'Cargando hogar…';

  @override
  String get homeSomethingWentWrong => 'Algo salió mal';

  @override
  String get homeTryAgain => 'Intentar de nuevo';

  @override
  String get homeWelcomeToPacelli => '¡Bienvenido a Pacelli!';

  @override
  String get homeWelcomeSubtitle =>
      'Las tareas de tu hogar aparecerán aquí.\nComencemos creando tu hogar.';

  @override
  String get homeCreateHousehold => 'Crear Hogar';

  @override
  String get homeHouseholdSetUp => '¡Tu hogar está configurado!';

  @override
  String get homeTodaysOverview => 'Resumen de Hoy';

  @override
  String get homeCompleted => 'Completadas';

  @override
  String get homePending => 'Pendientes';

  @override
  String get homeOverdue => 'Atrasadas';

  @override
  String get homeRecentTasks => 'Tareas Recientes';

  @override
  String get homeViewAll => 'Ver todo';

  @override
  String get homeFailedToLoadTasks => 'No se pudieron cargar las tareas';

  @override
  String get homeNoTasksYet =>
      'Aún no hay tareas — ¡aparecerán aquí cuando crees alguna!';

  @override
  String get homeCreateTask => 'Crear Tarea';

  @override
  String get homeCouldNotCompleteTask => 'No se pudo completar la tarea';

  @override
  String get homeDueToday => 'Vence hoy';

  @override
  String get homeDueTomorrow => 'Vence mañana';

  @override
  String homeDueDate(String date) {
    return 'Vence $date';
  }

  @override
  String get homeMyHousehold => 'Mi Hogar';

  @override
  String get taskNewTask => 'Nueva Tarea';

  @override
  String get taskTitle => 'Título de la tarea';

  @override
  String get taskTitleHint => 'ej. Limpiar la cocina';

  @override
  String get taskEnterTitle => 'Por favor, introduce un título';

  @override
  String get taskDescriptionOptional => 'Descripción (opcional)';

  @override
  String get taskDescriptionHint => 'Añade detalles...';

  @override
  String get taskCategory => 'Categoría';

  @override
  String get taskFailedToLoadCategories =>
      'No se pudieron cargar las categorías';

  @override
  String get taskNewCategory => 'Nueva Categoría';

  @override
  String get taskCategoryName => 'Nombre de categoría';

  @override
  String get taskPriority => 'Prioridad';

  @override
  String get taskPriorityLow => 'Baja';

  @override
  String get taskPriorityMedium => 'Media';

  @override
  String get taskPriorityHigh => 'Alta';

  @override
  String get taskPriorityUrgent => 'Urgente';

  @override
  String get taskStartsToday => 'Inicia: Hoy';

  @override
  String taskStartsDate(String date) {
    return 'Inicia: $date';
  }

  @override
  String get taskNoDueDate => 'Sin fecha límite';

  @override
  String taskDueDate(String date) {
    return 'Vence: $date';
  }

  @override
  String get taskAssignTo => 'Asignar a';

  @override
  String get taskSharedTask => 'Tarea compartida (ambos)';

  @override
  String get taskSharedTaskSubtitle => 'Cualquiera puede completarla';

  @override
  String get taskFailedToLoadMembers => 'No se pudieron cargar los miembros';

  @override
  String get taskMeSuffix => '(yo)';

  @override
  String get taskRepeat => 'Repetir';

  @override
  String get taskRepeatNever => 'Nunca';

  @override
  String get taskRepeatDaily => 'Diario';

  @override
  String get taskRepeatWeekly => 'Semanal';

  @override
  String get taskRepeatBiweekly => 'Cada 2 semanas';

  @override
  String get taskRepeatMonthly => 'Mensual';

  @override
  String get taskSubtasks => 'Subtareas';

  @override
  String get taskAddSubtaskHint => 'Añadir una subtarea...';

  @override
  String get taskDiscardTitle => '¿Descartar tarea?';

  @override
  String get taskDiscardMessage =>
      'Tienes cambios sin guardar. ¿Estás seguro de que quieres volver?';

  @override
  String get taskKeepEditing => 'Seguir editando';

  @override
  String get taskDiscard => 'Descartar';

  @override
  String get taskCreated => '¡Tarea creada!';

  @override
  String get taskEditTask => 'Editar Tarea';

  @override
  String get taskLoadingTask => 'Cargando tarea…';

  @override
  String get taskFailedToLoadTask => 'No se pudo cargar la tarea';

  @override
  String get taskNoHousehold => 'La tarea no tiene hogar';

  @override
  String get taskUpdated => '¡Tarea actualizada!';

  @override
  String get taskDetails => 'Detalles de Tarea';

  @override
  String get taskLoadingDetails => 'Cargando detalles de tarea…';

  @override
  String get taskCouldNotLoadDetails =>
      'No se pudieron cargar los detalles de la tarea.';

  @override
  String get taskDeleteTitle => '¿Eliminar tarea?';

  @override
  String get taskDeleteMessage =>
      'Esto eliminará permanentemente esta tarea y todas sus subtareas.';

  @override
  String get taskStatusCompleted => 'Completada';

  @override
  String get taskReopenTask => 'Reabrir Tarea';

  @override
  String get taskMarkComplete => 'Marcar Completada';

  @override
  String get taskLabelCategory => 'Categoría';

  @override
  String get taskLabelStarts => 'Inicia';

  @override
  String get taskLabelDue => 'Vence';

  @override
  String get taskLabelAssignedTo => 'Asignado a';

  @override
  String get taskSharedBoth => 'Compartida (ambos)';

  @override
  String get taskLabelRepeats => 'Se repite';

  @override
  String get taskLabelCreatedBy => 'Creado por';

  @override
  String get taskRemoveAttachmentTitle => '¿Eliminar adjunto?';

  @override
  String taskRemoveAttachmentMessage(String fileName) {
    return '¿Eliminar \"$fileName\" de esta tarea? El archivo permanecerá en Google Drive.';
  }

  @override
  String get taskRemove => 'Eliminar';

  @override
  String get taskAttachFile => 'Adjuntar un archivo';

  @override
  String get taskAttachAfterSave =>
      'Puedes adjuntar archivos después de guardar la tarea.';

  @override
  String taskPendingAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'archivos',
      one: 'archivo',
    );
    return '$count $_temp0 listo(s) para subir';
  }

  @override
  String get taskUploadingAttachments => 'Subiendo archivos adjuntos…';

  @override
  String get tasksTitle => 'Tareas';

  @override
  String get tasksCreateHouseholdFirst => 'Crea un hogar primero';

  @override
  String get tasksFilterAll => 'Todas';

  @override
  String get tasksFilterPending => 'Pendientes';

  @override
  String get tasksFilterDone => 'Hechas';

  @override
  String get tasksAllCategories => 'Todas las Categorías';

  @override
  String get tasksMore => 'Más';

  @override
  String get tasksCouldNotLoad => 'No se pudieron cargar las tareas.';

  @override
  String get tasksNoTasksYet => 'Aún no hay tareas.\n¡Toca + para crear una!';

  @override
  String get tasksAllCaughtUp => '¡Todo al día!';

  @override
  String get tasksNoCompletedYet => 'Aún no hay tareas completadas.';

  @override
  String get calendarTitle => 'Calendario';

  @override
  String get calendarActivePlans => 'Planes activos';

  @override
  String get calendarNewPlan => 'Nuevo Plan';

  @override
  String get calendarLoading => 'Cargando calendario…';

  @override
  String get calendarCouldNotLoad => 'No se pudo cargar el calendario.';

  @override
  String get calendarNoHousehold => 'Aún no tienes hogar';

  @override
  String get calendarLoadingTasks => 'Cargando tareas…';

  @override
  String get calendarCouldNotLoadTasks => 'No se pudieron cargar las tareas.';

  @override
  String get attachTitle => 'Adjuntar un Archivo';

  @override
  String get attachPickFile => 'Elegir un archivo';

  @override
  String get attachPickFileSubtitle =>
      'PDF, documento, hoja de cálculo o cualquier archivo';

  @override
  String get attachTakePhoto => 'Tomar una foto';

  @override
  String get attachTakePhotoSubtitle => 'Abrir la cámara';

  @override
  String get attachPickGallery => 'Elegir de la galería';

  @override
  String get attachPickGallerySubtitle => 'Seleccionar una foto existente';

  @override
  String get attachUploading => 'Subiendo archivo…';

  @override
  String get attachDriveNotSetUp =>
      'Google Drive no está configurado para este hogar. Pide al administrador del hogar que lo conecte.';

  @override
  String get attachDriveDisabled =>
      'El almacenamiento en Google Drive está desactivado actualmente.';

  @override
  String get attachSuccess => '¡Archivo adjuntado correctamente!';

  @override
  String attachUploadFailed(String error) {
    return 'Subida fallida: $error';
  }

  @override
  String get checklistNewChecklist => 'Nueva Lista';

  @override
  String get checklistHint => 'ej. Compras, Esenciales de Viaje';

  @override
  String get checklistAddItem => 'Añadir Elemento';

  @override
  String get checklistItemName => 'Nombre del elemento';

  @override
  String get checklistDeleteTitle => '¿Eliminar Lista?';

  @override
  String get checklistDeleteMessage =>
      'Esto eliminará la lista y todos sus elementos.';

  @override
  String get checklistCouldNotCreate => 'No se pudo crear la lista';

  @override
  String get checklistCouldNotAdd => 'No se pudo añadir el elemento';

  @override
  String get checklistCouldNotUpdate => 'No se pudo actualizar el elemento';

  @override
  String get checklistCouldNotPush => 'No se pudo enviar como tarea';

  @override
  String get checklistCouldNotDeleteItem => 'No se pudo eliminar el elemento';

  @override
  String get checklistCouldNotDeleteList => 'No se pudo eliminar la lista';

  @override
  String checklistAddedAsTask(String title) {
    return '\"$title\" añadido como tarea';
  }

  @override
  String checklistSectionTitle(int count) {
    return 'Listas · $count';
  }

  @override
  String get checklistNoChecklists => 'Aún no hay listas';

  @override
  String get checklistBadgePlan => 'Plan';

  @override
  String get checklistBadgeList => 'Lista';

  @override
  String get checklistPushAsTask => 'Enviar como Tarea';

  @override
  String checklistCountProgress(int checked, int total) {
    return '$checked/$total';
  }

  @override
  String get planNewPlan => 'Nuevo Plan';

  @override
  String get planStartFromTemplate => 'Empezar desde una plantilla';

  @override
  String get planWeeklyDinnerPlanner => 'Planificador Semanal de Cenas';

  @override
  String get planWeeklyDinnerDescription =>
      '7 cenas para la semana — una por día';

  @override
  String get planOrStartFromScratch => 'O empezar desde cero';

  @override
  String get planTitle => 'Título del plan';

  @override
  String get planTitleHint => 'ej. Menú Semanal, Viaje de Vacaciones';

  @override
  String get planGiveItAName => 'Dale un nombre';

  @override
  String get planTypeWeek => 'Semana';

  @override
  String get planTypeMonth => 'Mes';

  @override
  String get planTypeCustom => 'Personalizado';

  @override
  String get planCreatePlan => 'Crear Plan';

  @override
  String planFailedToCreate(String error) {
    return 'No se pudo crear el plan: $error';
  }

  @override
  String get planSelectDates => 'Selecciona fechas de inicio y fin';

  @override
  String get planConfirm => 'Confirmar';

  @override
  String planDaysCount(int count) {
    return '$count días';
  }

  @override
  String planStartsDate(String date) {
    return 'Inicia: $date';
  }

  @override
  String planTemplateEntries(String type, int count) {
    return 'Plan $type • $count entradas';
  }

  @override
  String get planLoadingPlan => 'Cargando plan…';

  @override
  String get planCouldNotLoad => 'No se pudo cargar el plan.';

  @override
  String get planInvalidMissingDates => 'Plan inválido: faltan fechas';

  @override
  String get planInvalidUnreadableDates => 'Plan inválido: fechas ilegibles';

  @override
  String get planSaveAsTemplate => 'Guardar como Plantilla';

  @override
  String get planTemplateName => 'Nombre de la plantilla';

  @override
  String get planFinalise => 'Finalizar';

  @override
  String get planFinalisedChip => 'Finalizado';

  @override
  String get planTapToAdd =>
      'Toca + para añadir comidas, actividades o lo que estés planeando.';

  @override
  String get planChecklist => 'Lista';

  @override
  String get planAddItemHint => 'Añadir elemento...';

  @override
  String get planNoItemsYet =>
      'Aún no hay elementos. Añade cosas que necesites comprar o hacer.';

  @override
  String planTemplateSaved(String name) {
    return '¡Plantilla \"$name\" guardada!';
  }

  @override
  String planFailedToSaveTemplate(String error) {
    return 'No se pudo guardar la plantilla: $error';
  }

  @override
  String planFailedToAddItem(String error) {
    return 'No se pudo añadir el elemento: $error';
  }

  @override
  String get planFinalisePlan => 'Finalizar Plan';

  @override
  String get planLoadingEntries => 'Cargando entradas del plan…';

  @override
  String get planPushToCalendar => '¿Enviar al Calendario?';

  @override
  String planPushSummary(int tasks, int notes) {
    return 'Se crearán $tasks tarea(s) y $notes nota(s).\n\nLas entradas omitidas no se añadirán al calendario.';
  }

  @override
  String get planPushToCalendarButton => 'Enviar al Calendario';

  @override
  String get planFinalisedSuccess => '¡Plan Finalizado!';

  @override
  String get planEntriesPushed => 'Tus entradas se han enviado al calendario.';

  @override
  String get planViewCalendar => 'Ver Calendario';

  @override
  String planFailedToFinalise(String error) {
    return 'No se pudo finalizar: $error';
  }

  @override
  String get planNoEntriesToFinalise => 'No hay entradas para finalizar.';

  @override
  String get planGoBack => 'Volver';

  @override
  String get planInfoBanner =>
      'Elige en qué se convierte cada entrada en tu calendario. Las tareas se pueden asignar y completar. Las notas son recordatorios ligeros.';

  @override
  String get planActionTask => 'Tarea';

  @override
  String get planActionNote => 'Nota';

  @override
  String get planActionSkip => 'Omitir';

  @override
  String get planLoadingDay => 'Cargando entradas del día…';

  @override
  String get planCouldNotLoadDay =>
      'No se pudieron cargar las entradas del día.';

  @override
  String planFailedToAdd(String error) {
    return 'No se pudo añadir: $error';
  }

  @override
  String planFailedToDelete(String error) {
    return 'No se pudo eliminar: $error';
  }

  @override
  String get planNewLabel => 'Nueva Etiqueta';

  @override
  String get planLabelHint => 'ej. Postre, Excursión';

  @override
  String get planEditEntry => 'Editar Entrada';

  @override
  String get planWhatsPlanned => '¿Qué hay planeado?';

  @override
  String get planCustomLabel => 'Personalizada';

  @override
  String planWhatsForLabel(String label) {
    return '¿Qué hay para $label?';
  }

  @override
  String planAddNeedsFor(String entry) {
    return 'Añadir necesidades para \"$entry\"';
  }

  @override
  String get planNeedsHint => 'ej. pasta, carne picada, tomates';

  @override
  String get planNeedsHelper => 'Separa con comas';

  @override
  String get planAddToList => 'Añadir a la Lista';

  @override
  String planItemsAddedToChecklist(int count) {
    return '$count elemento(s) añadido(s) a la lista';
  }

  @override
  String planFailedToUpdate(String error) {
    return 'No se pudo actualizar: $error';
  }

  @override
  String get planAddToChecklist => 'Añadir a la lista';

  @override
  String get planEdit => 'Editar';

  @override
  String get planLabelDinner => 'Cena';

  @override
  String get planLabelBreakfast => 'Desayuno';

  @override
  String get planLabelLunch => 'Almuerzo';

  @override
  String get planLabelSnack => 'Merienda';

  @override
  String get planLabelActivity => 'Actividad';

  @override
  String get planLabelTransport => 'Transporte';

  @override
  String get planLabelAccommodation => 'Alojamiento';

  @override
  String get householdCreateTitle => 'Crear Hogar';

  @override
  String get householdNameYour => 'Nombra tu hogar';

  @override
  String get householdNameSubtitle =>
      'Es lo que tú y tu pareja verán.\nPuedes cambiarlo en cualquier momento.';

  @override
  String get householdNameLabel => 'Nombre del hogar';

  @override
  String get householdNameHint => 'ej. El Hogar Celis';

  @override
  String get householdEnterName =>
      'Por favor, introduce un nombre para tu hogar';

  @override
  String get householdNameMinLength =>
      'El nombre debe tener al menos 2 caracteres';

  @override
  String get householdCreateButton => 'Crear Hogar';

  @override
  String get householdCreated => '¡Hogar creado! Bienvenido a casa.';

  @override
  String get householdCreateFailed =>
      'No se pudo crear el hogar. Inténtalo de nuevo.';

  @override
  String get householdTitle => 'Hogar';

  @override
  String get householdLoading => 'Cargando hogar…';

  @override
  String get householdCouldNotLoad => 'No se pudo cargar el hogar.';

  @override
  String get householdNotFound => 'No se encontró ningún hogar.';

  @override
  String get householdMyHousehold => 'Mi Hogar';

  @override
  String get householdRoleAdmin => 'Eres el administrador';

  @override
  String get householdRoleMember => 'Eres miembro';

  @override
  String get householdMembers => 'Miembros';

  @override
  String get householdLoadingMembers => 'Cargando miembros…';

  @override
  String get householdCouldNotLoadMembers =>
      'No se pudieron cargar los miembros. Desliza hacia abajo para reintentar.';

  @override
  String get householdYouSuffix => '(Tú)';

  @override
  String get householdRoleAdminLabel => 'Administrador';

  @override
  String get householdRoleMemberLabel => 'Miembro';

  @override
  String get householdStorageSection => 'Almacenamiento';

  @override
  String get householdFileStorage => 'Almacenamiento de Archivos';

  @override
  String get householdFileStorageSubtitle =>
      'Adjunta archivos a las tareas a través de Google Drive';

  @override
  String get householdInvitePartner => 'Invitar Pareja';

  @override
  String get householdInviteMessage =>
      'Envía una invitación al email de tu pareja. Se unirá a tu hogar cuando se registre o inicie sesión.';

  @override
  String get householdPartnerEmail => 'Email de tu pareja';

  @override
  String get householdPartnerEmailHint => 'pareja@ejemplo.com';

  @override
  String get householdInvite => 'Invitar';

  @override
  String get householdInviteValidEmail =>
      'Por favor, introduce un email válido.';

  @override
  String householdInviteSent(String email) {
    return '¡Invitación enviada a $email! Verá el hogar cuando se registre.';
  }

  @override
  String get householdInviteFailed =>
      'No se pudo enviar la invitación. Inténtalo de nuevo.';

  @override
  String get driveTitle => 'Almacenamiento de Archivos';

  @override
  String get driveConnected => 'Google Drive Conectado';

  @override
  String get driveConnect => 'Conectar Google Drive';

  @override
  String get driveConnectedSubtitle =>
      'Los archivos del hogar se almacenan en tu Google Drive.';

  @override
  String get driveConnectSubtitle =>
      'Almacena fotos, documentos y otros archivos junto a las tareas de tu hogar.';

  @override
  String get driveHowItWorks => 'CÓMO FUNCIONA';

  @override
  String get driveInfoFolder =>
      'Se crea una carpeta \"Pacelli\" en tu Google Drive.';

  @override
  String get driveInfoAttach =>
      'Adjunta fotos, PDFs u hojas de cálculo a cualquier tarea.';

  @override
  String get driveInfoMembers =>
      'Los miembros del hogar pueden ver los archivos adjuntos a través de enlaces.';

  @override
  String get driveInfoQuota =>
      'Los archivos usan TU cuota de Google Drive — sin costes adicionales.';

  @override
  String get drivePrivacyNote =>
      'Pacelli solo accede a los archivos que crea. No puede ver ni modificar tus otros archivos de Drive.';

  @override
  String get driveStorageActive => 'El almacenamiento de Drive está activo';

  @override
  String get driveCanAttachNow =>
      'Ahora puedes adjuntar archivos a las tareas.';

  @override
  String get drivePacelliFolder => 'Carpeta Pacelli en Google Drive';

  @override
  String get driveDisconnectTitle => '¿Desconectar Drive?';

  @override
  String get driveDisconnectMessage =>
      'Los adjuntos existentes seguirán accesibles a través de sus enlaces, pero no podrás subir archivos nuevos hasta que vuelvas a conectar.';

  @override
  String get driveDisconnect => 'Desconectar';

  @override
  String get driveConnectButton => 'Conectar Google Drive';

  @override
  String get driveDisconnectButton => 'Desconectar Google Drive';

  @override
  String get driveAdminOnly =>
      'Solo el administrador del hogar puede conectar o desconectar el almacenamiento de Google Drive.';

  @override
  String get driveAccessNotGranted =>
      'No se concedió acceso a Drive. Inténtalo de nuevo.';

  @override
  String get driveConnectedSuccess => '¡Google Drive conectado correctamente!';

  @override
  String driveConnectFailed(String error) {
    return 'No se pudo conectar Google Drive: $error';
  }

  @override
  String get driveDisconnected => 'Google Drive desconectado.';

  @override
  String driveDisconnectFailed(String error) {
    return 'No se pudo desconectar: $error';
  }

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsHousehold => 'Hogar';

  @override
  String get settingsHouseholdSubtitle => 'Gestionar hogar y miembros';

  @override
  String get settingsNotifications => 'Notificaciones';

  @override
  String get settingsNotificationsSubtitle => 'Recordatorios y alertas';

  @override
  String get settingsPrivacy => 'Privacidad y Cifrado';

  @override
  String get settingsPrivacySubtitle => 'Cómo se protegen tus datos';

  @override
  String get settingsDataStorage => 'Almacenamiento de Datos';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsAppearanceSubtitle => 'Tema y pantalla';

  @override
  String get settingsAbout => 'Acerca de Pacelli';

  @override
  String get settingsAboutVersion => 'Versión 1.0.0';

  @override
  String get settingsSignOut => 'Cerrar Sesión';

  @override
  String get settingsSignOutFailed =>
      'No se pudo cerrar sesión. Inténtalo de nuevo.';

  @override
  String settingsComingSoon(String feature) {
    return 'Los ajustes de $feature llegarán en una actualización futura. ¡Estén atentos!';
  }

  @override
  String get settingsAboutDescription =>
      'Pacelli ayuda a tu hogar a mantenerse organizado — tareas, planes, listas y más, todo en un solo lugar.';

  @override
  String get settingsDataStorageTitle => 'Almacenamiento de Datos';

  @override
  String get settingsCurrentBackend => 'Backend actual:';

  @override
  String get settingsBackendLocal => 'En Este Dispositivo (SQLite)';

  @override
  String get settingsBackendCloud => 'Sincronización en la Nube (Firebase)';

  @override
  String get settingsEndToEndEncrypted => 'Cifrado de extremo a extremo';

  @override
  String get settingsSwitchBackend =>
      'Para cambiar de backend, toca \"Cambiar\" abajo. Nota: los datos existentes no se migrarán automáticamente.';

  @override
  String get settingsDangerZone => 'ZONA DE PELIGRO';

  @override
  String get settingsBurnAllData => 'Destruir Todos Mis Datos';

  @override
  String get settingsBurnExplanation =>
      'Elimina permanentemente todos tus datos, ajustes guardados y cierra sesión. Esto no se puede deshacer.';

  @override
  String get settingsBurnTitle => '¿Destruir Todos los Datos?';

  @override
  String get settingsBurnWillDelete => 'Esto eliminará permanentemente:';

  @override
  String get settingsBurnTasks => 'Todas las tareas, planes y listas';

  @override
  String get settingsBurnCategories => 'Todas las categorías y ajustes';

  @override
  String get settingsBurnLocalDb => 'Base de datos local (si se usa)';

  @override
  String get settingsBurnCloudData =>
      'Datos en la nube (si usa Sincronización en la Nube)';

  @override
  String get settingsBurnKeys => 'Claves de cifrado y preferencias guardadas';

  @override
  String get settingsBurnCredentials =>
      'Tu nombre de usuario y contraseña (cierre de sesión completo)';

  @override
  String get settingsBurnSession =>
      'Tu sesión — necesitarás iniciar sesión de nuevo';

  @override
  String get settingsBurnIrreversible =>
      'Esta acción es irreversible. No hay forma de recuperar tus datos después de esto.';

  @override
  String get settingsBurnEverything => 'Destruir Todo';

  @override
  String get privacyTitle => 'Privacidad y Cifrado';

  @override
  String get privacyE2ETitle => 'Cifrado de Extremo a Extremo';

  @override
  String get privacyE2ESubtitle =>
      'Cifrado AES-256 — el mismo estándar utilizado por bancos y gobiernos.';

  @override
  String get privacyHowProtected => 'Cómo se protegen tus datos';

  @override
  String get privacyAllContent =>
      'Todo tu contenido personal — nombres de tareas, descripciones, títulos de planes, elementos de listas, el nombre de tu hogar — se cifra de extremo a extremo antes de salir de tu dispositivo.';

  @override
  String get privacyOnlyYou =>
      'Solo tú y los miembros de tu hogar pueden leer tus datos. Ni siquiera los desarrolladores de la app pueden verlos.';

  @override
  String get privacyWhatEncrypted => 'Qué se cifra';

  @override
  String get privacyTaskTitles => 'Títulos y descripciones de tareas';

  @override
  String get privacySubtaskTitles => 'Títulos de subtareas';

  @override
  String get privacyChecklistTitles =>
      'Títulos de listas y elementos de listas';

  @override
  String get privacyPlanTitles =>
      'Títulos de planes, títulos de entradas, etiquetas y descripciones';

  @override
  String get privacyCategoryNames => 'Nombres de categorías';

  @override
  String get privacyHouseholdName => 'Nombre del hogar';

  @override
  String get privacyDisplayName => 'Tu nombre visible';

  @override
  String get privacyAttachmentNames => 'Nombres y descripciones de adjuntos';

  @override
  String get privacyAttachmentMetadata =>
      'Metadatos de adjuntos (tipo de archivo, enlaces, miniaturas)';

  @override
  String get privacyWhatNotEncrypted => 'Qué no se cifra';

  @override
  String get privacyTaskStatus =>
      'Estado de la tarea (pendiente, completada, etc.)';

  @override
  String get privacyPriorityLevels =>
      'Niveles de prioridad (baja, media, alta, urgente)';

  @override
  String get privacyDueDates => 'Fechas límite y marcas de tiempo';

  @override
  String get privacyCheckedStatus =>
      'Si los elementos están marcados o completados';

  @override
  String get privacySortOrder =>
      'Orden de clasificación y ajustes de visualización';

  @override
  String get privacyCategoryIcons => 'Iconos y colores de categorías';

  @override
  String get privacyFileAttachments => 'Adjuntos de archivos (Google Drive)';

  @override
  String get privacyDriveExplanation =>
      'Los archivos que adjuntas a las tareas se almacenan en el Google Drive del propietario del hogar, en una carpeta dedicada \"Pacelli\". Los nombres y descripciones de archivos se cifran en la base de datos de Pacelli, pero los archivos reales en Google Drive están protegidos por la seguridad propia de Google — no por el cifrado E2E de Pacelli.';

  @override
  String get privacyDriveAccess =>
      'Los miembros del hogar acceden a los archivos a través de enlaces compartidos de solo lectura. Los archivos se almacenan usando la cuota de Google Drive del propietario — sin costes adicionales para la app.';

  @override
  String get privacyWhyNotEncrypted => 'Por qué algunos campos no se cifran';

  @override
  String get privacyWhyExplanation =>
      'Estos campos estructurales son necesarios para que la app filtre, ordene y organice tus datos en el servidor. No contienen información personal — son etiquetas como \"completada\" o \"alta prioridad\", no tu contenido real.';

  @override
  String get privacyYourControl => 'Tus datos, tu control';

  @override
  String get privacyDeleteAll =>
      'Puedes eliminar TODOS tus datos en cualquier momento usando \"Destruir Todos Mis Datos\" en Ajustes. Cuando eliminas tus datos, el contenido cifrado se elimina permanentemente de nuestros servidores.';

  @override
  String get privacyKeyGeneration =>
      'Tu clave de cifrado se genera en tu dispositivo y nunca se almacena en forma legible en el servidor. Cada miembro del hogar recibe su propia copia cifrada de la clave compartida.';

  @override
  String get storageWhereDataLive => '¿Dónde deben vivir tus datos?';

  @override
  String get storageSubtitle =>
      'Tus tareas, planes y listas son tuyas. Elige dónde guardarlas.';

  @override
  String get storageOnDevice => 'En Este Dispositivo';

  @override
  String get storageOnDeviceDescription =>
      'Los datos se quedan en tu teléfono. Sin nube, sin sincronización, total privacidad.';

  @override
  String get storageCloudSync => 'Sincronización en la Nube';

  @override
  String get storageCloudSyncDescription =>
      'Sincronización multidispositivo en tiempo real. Todo tu contenido está cifrado de extremo a extremo.';

  @override
  String get storageRecommended => 'Recomendado';

  @override
  String get storagePrivacyNote =>
      'La Sincronización en la Nube usa cifrado AES-256 de extremo a extremo. Tu contenido personal (nombres de tareas, descripciones, elementos de listas) se cifra en tu dispositivo antes de salir. Ni siquiera nosotros podemos leerlo.';

  @override
  String storageFailedLocal(String error) {
    return 'No se pudo configurar el almacenamiento local: $error';
  }

  @override
  String storageFailedCloud(String error) {
    return 'No se pudo configurar la sincronización en la nube: $error';
  }

  @override
  String get errorDefault => 'Algo salió mal.\nInténtalo de nuevo.';

  @override
  String get taskRecurrenceDaily => 'Diario';

  @override
  String get taskRecurrenceWeekly => 'Semanal';

  @override
  String get taskRecurrenceBiweekly => 'Cada 2 semanas';

  @override
  String get taskRecurrenceMonthly => 'Mensual';

  @override
  String taskSubtaskProgress(int completed, int total) {
    return '$completed/$total';
  }

  @override
  String get taskNew => 'Nueva';

  @override
  String get commonNew => 'Nueva';

  @override
  String get commonOK => 'OK';

  @override
  String get taskAddSubtask => 'Añadir una subtarea...';

  @override
  String get taskDescription => 'Descripción (opcional)';

  @override
  String get taskLabelAssignTo => 'Asignar a';

  @override
  String get taskLabelPriority => 'Prioridad';

  @override
  String get taskLabelRepeat => 'Repetir';

  @override
  String get taskRecurrenceNone => 'Nunca';

  @override
  String get taskUnassigned => 'Sin asignar';

  @override
  String get tasksFailedToLoadHousehold => 'No se pudo cargar el hogar';

  @override
  String get tasksLoadingHousehold => 'Cargando hogar…';

  @override
  String get navHome => 'Inicio';

  @override
  String get navTasks => 'Tareas';

  @override
  String get navCalendar => 'Calendario';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get priorityUrgent => 'Urgente';

  @override
  String get priorityHigh => 'Alta';

  @override
  String get priorityMedium => 'Media';

  @override
  String get priorityLow => 'Baja';

  @override
  String get priorityNone => 'Ninguna';

  @override
  String get recurrenceDaily => 'Diario';

  @override
  String get recurrenceWeekly => 'Semanal';

  @override
  String get recurrenceEveryTwoWeeks => 'Cada 2 semanas';

  @override
  String get recurrenceMonthly => 'Mensual';

  @override
  String get recurrenceNever => 'Nunca';

  @override
  String calendarTasksSectionTitle(String dayLabel, int count) {
    return 'Tareas · $dayLabel · $count';
  }

  @override
  String get calendarNoTasksOnDay => 'No hay tareas este día';

  @override
  String calendarPlansSectionTitle(int count) {
    return 'Planes · $count';
  }

  @override
  String get calendarNoDraftPlans => 'Sin planes en borrador';

  @override
  String calendarPlanEntries(int count) {
    return '$count entradas';
  }

  @override
  String calendarChecklistItems(int count) {
    return '$count elementos de lista';
  }

  @override
  String get settingsBurnDriveWarning =>
      'Ten en cuenta — esto no eliminará tu carpeta de Pacelli en Google Drive ni los archivos en tu dispositivo. Tendrás que eliminarlos manualmente si lo deseas.';

  @override
  String get settingsBurnDriveWarningShort =>
      'Los archivos en Google Drive o almacenamiento local deben eliminarse manualmente.';

  @override
  String get burnStatusBurning => 'Quemando tus datos...';

  @override
  String get burnStatusDestroying => 'Destruyendo tus datos...';

  @override
  String get burnStatusClearingLocal => 'Limpiando almacenamiento local...';

  @override
  String get burnStatusClearingKeys => 'Eliminando claves de cifrado...';

  @override
  String get burnStatusSigningOut => 'Cerrando sesión...';

  @override
  String get burnStatusRemovingSettings => 'Eliminando ajustes guardados...';

  @override
  String get burnStatusComplete => 'Todos los datos han sido destruidos.';

  @override
  String get burnStatusError => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get burnPasswordTitle => 'Confirmar eliminación de cuenta';

  @override
  String get burnPasswordMessage =>
      'Para eliminar permanentemente tu cuenta y todos los datos, ingresa tu contraseña.';

  @override
  String get burnPasswordHint => 'Contraseña';

  @override
  String get burnPasswordConfirm => 'Eliminar todo';

  @override
  String get burnPasswordError => 'Contraseña incorrecta. Inténtalo de nuevo.';

  @override
  String get appearanceTitle => 'Apariencia';

  @override
  String get appearanceThemeMode => 'Modo del tema';

  @override
  String get appearanceThemeModeSubtitle =>
      'Elige claro, oscuro o sigue los ajustes del dispositivo';

  @override
  String get appearanceModeSystem => 'Auto';

  @override
  String get appearanceModeLight => 'Claro';

  @override
  String get appearanceModeDark => 'Oscuro';

  @override
  String get appearanceColorScheme => 'Paleta de colores';

  @override
  String get appearanceColorSchemeSubtitle => 'Elige una paleta que te guste';

  @override
  String get appearanceSchemePacelli => 'Pacelli';

  @override
  String get appearanceSchemePacelliDesc => 'Verde salvia y terracota';

  @override
  String get appearanceSchemeClaude => 'Claude';

  @override
  String get appearanceSchemeClaudeDesc => 'Púrpura cálido y coral';

  @override
  String get appearanceSchemeGemini => 'Gemini';

  @override
  String get appearanceSchemeGeminiDesc => 'Azul océano y coral';

  @override
  String attachCount(int count) {
    return 'Adjuntos ($count)';
  }

  @override
  String get attachInvalidLink => 'Enlace no válido.';

  @override
  String get attachCouldNotOpen => 'No se pudo abrir el archivo.';

  @override
  String get attachRemoveTooltip => 'Eliminar adjunto';

  @override
  String get planAttachFile => 'Adjuntar archivo';

  @override
  String get planRemoveAttachmentTitle => '¿Eliminar adjunto?';

  @override
  String planRemoveAttachmentMessage(String fileName) {
    return '¿Eliminar \"$fileName\" de esta entrada? El archivo permanecerá en Google Drive.';
  }

  @override
  String planAttachmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'archivos',
      one: 'archivo',
    );
    return '$count $_temp0';
  }

  @override
  String get notifTitle => 'Notificaciones';

  @override
  String get notifEnable => 'Activar notificaciones';

  @override
  String get notifEnableSubtitle =>
      'Recibe recordatorios cuando las tareas venzan';

  @override
  String get notifTimingTitle => 'Momento del recordatorio';

  @override
  String get notifTimingSubtitle =>
      '¿Cuándo quieres que te recordemos las tareas pendientes?';

  @override
  String get notifTimingAtDue => 'Al vencer';

  @override
  String get notifTimingAtDueDesc => 'Notificar justo cuando la tarea vence';

  @override
  String get notifTimingOneHour => '1 hora antes';

  @override
  String get notifTimingOneHourDesc => 'Recibir un aviso una hora antes';

  @override
  String get notifTimingOneDay => '1 día antes';

  @override
  String get notifTimingOneDayDesc => 'Recordar a las 9 AM del día anterior';

  @override
  String get notifInfoNote =>
      'Las notificaciones se envían localmente en este dispositivo. Funcionan incluso con la app cerrada.';

  @override
  String get settingsImportExport => 'Importar / Exportar';

  @override
  String get settingsImportExportSubtitle =>
      'Respaldo y restauración de tus datos';

  @override
  String get ieTitle => 'Importar / Exportar';

  @override
  String get ieExportSection => 'EXPORTAR';

  @override
  String get ieExportJson => 'Exportar como JSON';

  @override
  String get ieExportJsonDesc =>
      'Respaldo completo de tareas, listas, planes e inventario';

  @override
  String get ieExportCsv => 'Exportar tareas como CSV';

  @override
  String get ieExportCsvDesc => 'Lista de tareas en formato de hoja de cálculo';

  @override
  String get ieExportSuccess => 'Exportación guardada correctamente.';

  @override
  String ieExportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String ieLastExport(String date) {
    return 'Última exportación: $date';
  }

  @override
  String get ieImportSection => 'IMPORTAR';

  @override
  String get ieImportButton => 'Importar desde respaldo';

  @override
  String get ieImportDesc => 'Restaurar datos desde un archivo JSON de Pacelli';

  @override
  String get ieImportReading => 'Leyendo archivo...';

  @override
  String ieImportInvalid(String error) {
    return 'Archivo de respaldo inválido: $error';
  }

  @override
  String get ieImportConfirmTitle => '¿Importar datos?';

  @override
  String get ieImportConfirmMessage =>
      'Esto agregará los datos del respaldo a tu hogar actual. Los datos existentes no se eliminarán.';

  @override
  String ieImportSuccess(int created, int skipped) {
    return 'Importación completa. $created elementos creados, $skipped omitidos.';
  }

  @override
  String ieImportFailed(String error) {
    return 'Error al importar: $error';
  }

  @override
  String get ieInfoNote =>
      'Los archivos exportados se guardan en texto plano. Si tus datos están cifrados en la nube, se descifrarán para la exportación.';

  @override
  String get searchTitle => 'Buscar';

  @override
  String get searchHint => 'Buscar tareas, listas, planes...';

  @override
  String get searchNoResults => 'No se encontraron resultados';

  @override
  String get searchFilterTasks => 'Tareas';

  @override
  String get searchFilterChecklists => 'Listas';

  @override
  String get searchFilterPlans => 'Planes';

  @override
  String get searchFilterAttachments => 'Adjuntos';

  @override
  String get searchLoading => 'Buscando...';

  @override
  String get searchEmptyState => 'Empieza a escribir para buscar en tu hogar';

  @override
  String get searchResultTask => 'Tarea';

  @override
  String get searchResultChecklist => 'Lista';

  @override
  String get searchResultPlan => 'Plan';

  @override
  String get searchResultAttachment => 'Adjunto';

  @override
  String get searchResultInventory => 'Inventario';

  @override
  String get inventoryTitle => 'Inventario';

  @override
  String get inventoryEmpty =>
      'Tu inventario está vacío — toca + para añadir tu primer artículo';

  @override
  String inventoryItemCount(int count) {
    return '$count artículos';
  }

  @override
  String get inventoryLowStock => 'Stock bajo';

  @override
  String get inventoryExpiringSoon => 'Por vencer';

  @override
  String get inventoryAddItem => 'Añadir Artículo';

  @override
  String get inventoryEditItem => 'Editar Artículo';

  @override
  String get inventoryItemName => 'Nombre del artículo';

  @override
  String get inventoryItemNameHint => 'ej. Aceite de oliva, Papel de cocina';

  @override
  String get inventoryDescription => 'Descripción';

  @override
  String get inventoryCategory => 'Categoría';

  @override
  String get inventoryLocation => 'Ubicación';

  @override
  String get inventoryQuantity => 'Cantidad';

  @override
  String get inventoryUnit => 'Unidad';

  @override
  String get inventoryUnitPieces => 'unidades';

  @override
  String get inventoryUnitKg => 'kg';

  @override
  String get inventoryUnitLitres => 'litros';

  @override
  String get inventoryUnitBags => 'bolsas';

  @override
  String get inventoryUnitBoxes => 'cajas';

  @override
  String get inventoryLowStockThreshold => 'Umbral de stock bajo';

  @override
  String get inventoryExpiryDate => 'Fecha de vencimiento';

  @override
  String get inventoryPurchaseDate => 'Fecha de compra';

  @override
  String get inventoryNotes => 'Notas';

  @override
  String get inventoryBarcode => 'Código de barras';

  @override
  String get inventoryBarcodeNone => 'Sin código de barras';

  @override
  String get inventoryBarcodeReal => 'Código de barras del producto';

  @override
  String get inventoryBarcodeVirtual => 'Código de barras virtual';

  @override
  String get inventorySave => 'Guardar artículo';

  @override
  String get inventoryDelete => 'Eliminar artículo';

  @override
  String get inventoryDeleteConfirm =>
      '¿Estás seguro de que quieres eliminar este artículo? Esta acción no se puede deshacer.';

  @override
  String get inventoryCategories => 'Categorías';

  @override
  String get inventoryLocations => 'Ubicaciones';

  @override
  String get inventoryManageCategories => 'Gestionar Categorías';

  @override
  String get inventoryManageLocations => 'Gestionar Ubicaciones';

  @override
  String get inventoryAddCategory => 'Añadir Categoría';

  @override
  String get inventoryAddLocation => 'Añadir Ubicación';

  @override
  String get inventoryCategoryName => 'Nombre de categoría';

  @override
  String get inventoryLocationName => 'Nombre de ubicación';

  @override
  String get inventoryCannotDeleteCategory =>
      'No se puede eliminar — hay artículos usando esta categoría';

  @override
  String get inventoryCannotDeleteLocation =>
      'No se puede eliminar — hay artículos usando esta ubicación';

  @override
  String inventoryLogAdded(int count) {
    return 'Añadido $count';
  }

  @override
  String inventoryLogRemoved(int count) {
    return 'Usado $count';
  }

  @override
  String inventoryLogAdjusted(int count) {
    return 'Ajustado a $count';
  }

  @override
  String get inventoryActivityLog => 'Registro de Actividad';

  @override
  String get inventoryViewByCategory => 'Por Categoría';

  @override
  String get inventoryViewByLocation => 'Por Ubicación';

  @override
  String get inventoryViewAll => 'Todos los Artículos';

  @override
  String get inventoryDetails => 'Detalles';

  @override
  String get inventoryAttachments => 'Adjuntos';

  @override
  String inventoryCreatedBy(String name) {
    return 'Añadido por $name';
  }

  @override
  String inventoryItemsExpiring(int count) {
    return '$count por vencer';
  }

  @override
  String inventoryItemsLowStock(int count) {
    return '$count stock bajo';
  }

  @override
  String get inventoryNoExpiry => 'Sin fecha de vencimiento';

  @override
  String inventoryExpiresIn(int days) {
    return 'Vence en $days días';
  }

  @override
  String get inventoryExpired => 'Vencido';

  @override
  String get inventoryExpiresToday => 'Vence hoy';

  @override
  String get inventoryDiscardTitle => '¿Descartar cambios?';

  @override
  String get inventoryDiscardMessage =>
      'Tienes cambios sin guardar. ¿Estás seguro de que quieres volver?';

  @override
  String get inventoryKeepEditing => 'Seguir editando';

  @override
  String get inventoryDiscard => 'Descartar';

  @override
  String get inventoryCreated => '¡Artículo añadido!';

  @override
  String get inventoryUpdated => '¡Artículo actualizado!';

  @override
  String get inventoryDeleted => 'Artículo eliminado';

  @override
  String get inventoryCouldNotLoad => 'No se pudo cargar el inventario';

  @override
  String get inventoryUncategorised => 'Sin categoría';

  @override
  String get inventoryNoLocation => 'Sin ubicación';

  @override
  String get inventoryIconLabel => 'Icono';

  @override
  String get inventoryColorLabel => 'Color';

  @override
  String get inventoryCategoryCreated => 'Categoría creada';

  @override
  String get inventoryLocationCreated => 'Ubicación creada';

  @override
  String get inventoryCategoryDeleted => 'Categoría eliminada';

  @override
  String get inventoryLocationDeleted => 'Ubicación eliminada';

  @override
  String get inventoryCouldNotDelete => 'No se pudo eliminar';

  @override
  String get inventoryScanBarcode => 'Escanear Código';

  @override
  String get inventoryScanPrompt =>
      'Apunta la cámara a un código de barras o QR';

  @override
  String get inventoryScanNotFound =>
      'No se encontró ningún artículo con este código';

  @override
  String inventoryScanFoundItem(String name) {
    return 'Encontrado: $name';
  }

  @override
  String get inventoryBarcodeTypeLabel => 'Tipo de código';

  @override
  String get inventoryBarcodeTypeNone => 'Sin código';

  @override
  String get inventoryBarcodeTypeReal => 'Escanear código del producto';

  @override
  String get inventoryBarcodeTypeVirtual => 'Generar QR virtual';

  @override
  String get inventoryTapToScan => 'Toca para escanear';

  @override
  String get inventoryVirtualBarcodeGenerated => 'QR virtual generado';

  @override
  String get inventoryViewQrCode => 'Ver Código QR';

  @override
  String get inventoryQrCodeTitle => 'Código Virtual';

  @override
  String get inventoryQrCodeSubtitle =>
      'Escanea este código QR para encontrar este artículo';

  @override
  String get inventoryBatchCreate => 'Creación en Lote';

  @override
  String get inventoryBatchTitle => 'Crear Artículos en Lote';

  @override
  String get inventoryBatchPortions => 'Número de porciones';

  @override
  String get inventoryBatchPortionsHint =>
      'Cuántos artículos crear a partir de este';

  @override
  String inventoryBatchNamePattern(String name, int index, int total) {
    return '$name ($index/$total)';
  }

  @override
  String inventoryBatchCreated(int count) {
    return '¡$count artículos creados!';
  }

  @override
  String get inventoryCameraPermissionDenied =>
      'Se necesita permiso de cámara para escanear códigos';

  @override
  String inventoryExpiringNotification(String name) {
    return '$name caduca pronto';
  }

  @override
  String inventoryLowStockNotification(String name, int count) {
    return '$name se está agotando ($count restantes)';
  }

  @override
  String get inventoryCreateRestockTask => '¿Crear tarea de reposición?';

  @override
  String inventoryRestockTaskTitle(String name) {
    return 'Reponer: $name';
  }

  @override
  String inventoryExpiryTaskTitle(String name) {
    return 'Usar antes de que caduque: $name';
  }

  @override
  String get inventoryRestockTaskCreated => 'Tarea de reposición creada';

  @override
  String get inventoryExpiryTaskCreated => 'Tarea de caducidad creada';

  @override
  String get inventoryAutoCreateTask => 'Crear tarea';

  @override
  String get inventoryNotificationSent => 'Notificación enviada';

  @override
  String get inventoryItemExpired => 'Artículo caducado';

  @override
  String get inventoryCalendarExpiring => 'Artículos por caducar';

  @override
  String get inventoryLowStockAlert => '¡Stock bajo! ¿Crear tarea de compra?';

  @override
  String inventoryThresholdCrossed(String name, int threshold) {
    return '$name bajó de $threshold';
  }

  @override
  String get inventoryExpiryCalendarDot => 'Artículo por caducar';

  @override
  String get inventoryActivityLogEmpty => 'Sin actividad aún';

  @override
  String get inventoryDefaultLabel => 'Predeterminado';

  @override
  String get commonErrorGeneric => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get homeInventorySnapshot => 'Inventario';

  @override
  String get homeInvTotal => 'Total';

  @override
  String homeInventorySummary(int count, int alert) {
    return '$count artículos · $alert alerta';
  }

  @override
  String homeInventorySummaryPlural(int count, int alert) {
    return '$count artículos · $alert alertas';
  }
}
