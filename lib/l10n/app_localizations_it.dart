// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonAdd => 'Aggiungi';

  @override
  String get commonCreate => 'Crea';

  @override
  String get commonClose => 'Chiudi';

  @override
  String get commonChange => 'Cambia';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Riprova';

  @override
  String get commonToday => 'Oggi';

  @override
  String get commonTomorrow => 'Domani';

  @override
  String get commonUnassigned => 'Non assegnato';

  @override
  String get commonUnknown => 'Sconosciuto';

  @override
  String get commonUntitled => 'Senza titolo';

  @override
  String get commonShared => 'Condiviso';

  @override
  String commonError(String error) {
    return 'Errore: $error';
  }

  @override
  String get authWelcomeBack => 'Bentornato';

  @override
  String get authSignInToHousehold => 'Accedi alla tua casa';

  @override
  String get authOrSignInWithEmail => 'oppure accedi con email';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authEnterEmail => 'Inserisci la tua email';

  @override
  String get authEnterValidEmail => 'Inserisci un\'email valida';

  @override
  String get authEnterPassword => 'Inserisci la tua password';

  @override
  String get authPasswordMinLength =>
      'La password deve avere almeno 6 caratteri';

  @override
  String get authEnterEmailFirst => 'Inserisci prima la tua email';

  @override
  String get authPasswordResetSent =>
      'Email di recupero password inviata! Controlla la tua posta.';

  @override
  String get authForgotPassword => 'Password dimenticata?';

  @override
  String get authSignIn => 'Accedi';

  @override
  String get authNoAccount => 'Non hai un account? ';

  @override
  String get authSignUp => 'Registrati';

  @override
  String get authContinueWithGoogle => 'Continua con Google';

  @override
  String get authGoogleSignInFailed =>
      'Accesso con Google non riuscito. Riprova.';

  @override
  String get authLoginFailed =>
      'Accesso non riuscito. Controlla email e password.';

  @override
  String get authCreateAccount => 'Crea account';

  @override
  String get authStartOrganising =>
      'Inizia a organizzare la tua casa con amore';

  @override
  String get authOrSignUpWithEmail => 'oppure registrati con email';

  @override
  String get authFullName => 'Nome completo';

  @override
  String get authConfirmPassword => 'Conferma password';

  @override
  String get authEnterName => 'Inserisci il tuo nome';

  @override
  String get authEnterAPassword => 'Inserisci una password';

  @override
  String get authPasswordMin8 => 'La password deve avere almeno 8 caratteri';

  @override
  String get authPasswordsDoNotMatch => 'Le password non corrispondono';

  @override
  String get authCreateAccountButton => 'Crea Account';

  @override
  String get authAlreadyHaveAccount => 'Hai già un account? ';

  @override
  String get authAccountCreated => 'Account creato! Benvenuto su Pacelli.';

  @override
  String get authSignupFailed => 'Registrazione non riuscita. Riprova.';

  @override
  String get authAppName => 'Pacelli';

  @override
  String get authTagline => 'Una casa serena, organizzata con amore.';

  @override
  String homeHelloGreeting(String userName) {
    return 'Ciao, $userName';
  }

  @override
  String get homeLoadingHousehold => 'Caricamento casa…';

  @override
  String get homeSomethingWentWrong => 'Qualcosa è andato storto';

  @override
  String get homeTryAgain => 'Riprova';

  @override
  String get homeWelcomeToPacelli => 'Benvenuto su Pacelli!';

  @override
  String get homeWelcomeSubtitle =>
      'Le attività della tua casa appariranno qui.\nIniziamo creando la tua casa.';

  @override
  String get homeCreateHousehold => 'Crea Casa';

  @override
  String get homeHouseholdSetUp => 'La tua casa è configurata!';

  @override
  String get homeTodaysOverview => 'Riepilogo di Oggi';

  @override
  String get homeCompleted => 'Completate';

  @override
  String get homePending => 'In sospeso';

  @override
  String get homeOverdue => 'In ritardo';

  @override
  String get homeRecentTasks => 'Attività Recenti';

  @override
  String get homeViewAll => 'Vedi tutto';

  @override
  String get homeFailedToLoadTasks => 'Impossibile caricare le attività';

  @override
  String get homeNoTasksYet =>
      'Nessuna attività — appariranno qui quando ne creerai!';

  @override
  String get homeCreateTask => 'Crea Attività';

  @override
  String get homeCouldNotCompleteTask => 'Impossibile completare l\'attività';

  @override
  String get homeDueToday => 'Scade oggi';

  @override
  String get homeDueTomorrow => 'Scade domani';

  @override
  String homeDueDate(String date) {
    return 'Scade il $date';
  }

  @override
  String get homeMyHousehold => 'La Mia Casa';

  @override
  String get taskNewTask => 'Nuova Attività';

  @override
  String get taskTitle => 'Titolo attività';

  @override
  String get taskTitleHint => 'es. Pulire la cucina';

  @override
  String get taskEnterTitle => 'Inserisci un titolo';

  @override
  String get taskDescriptionOptional => 'Descrizione (facoltativa)';

  @override
  String get taskDescriptionHint => 'Aggiungi dettagli...';

  @override
  String get taskCategory => 'Categoria';

  @override
  String get taskFailedToLoadCategories => 'Impossibile caricare le categorie';

  @override
  String get taskNewCategory => 'Nuova Categoria';

  @override
  String get taskCategoryName => 'Nome categoria';

  @override
  String get taskPriority => 'Priorità';

  @override
  String get taskPriorityLow => 'Bassa';

  @override
  String get taskPriorityMedium => 'Media';

  @override
  String get taskPriorityHigh => 'Alta';

  @override
  String get taskPriorityUrgent => 'Urgente';

  @override
  String get taskStartsToday => 'Inizio: Oggi';

  @override
  String taskStartsDate(String date) {
    return 'Inizio: $date';
  }

  @override
  String get taskNoDueDate => 'Nessuna scadenza';

  @override
  String taskDueDate(String date) {
    return 'Scadenza: $date';
  }

  @override
  String get taskAssignTo => 'Assegna a';

  @override
  String get taskSharedTask => 'Attività condivisa (entrambi)';

  @override
  String get taskSharedTaskSubtitle => 'Chiunque può completarla';

  @override
  String get taskFailedToLoadMembers => 'Impossibile caricare i membri';

  @override
  String get taskMeSuffix => '(io)';

  @override
  String get taskRepeat => 'Ripeti';

  @override
  String get taskRepeatNever => 'Mai';

  @override
  String get taskRepeatDaily => 'Giornaliero';

  @override
  String get taskRepeatWeekly => 'Settimanale';

  @override
  String get taskRepeatBiweekly => 'Ogni 2 settimane';

  @override
  String get taskRepeatMonthly => 'Mensile';

  @override
  String get taskSubtasks => 'Sotto-attività';

  @override
  String get taskAddSubtaskHint => 'Aggiungi una sotto-attività...';

  @override
  String get taskDiscardTitle => 'Annullare l\'attività?';

  @override
  String get taskDiscardMessage =>
      'Hai modifiche non salvate. Sei sicuro di voler tornare indietro?';

  @override
  String get taskKeepEditing => 'Continua a modificare';

  @override
  String get taskDiscard => 'Annulla';

  @override
  String get taskCreated => 'Attività creata!';

  @override
  String get taskEditTask => 'Modifica Attività';

  @override
  String get taskLoadingTask => 'Caricamento attività…';

  @override
  String get taskFailedToLoadTask => 'Impossibile caricare l\'attività';

  @override
  String get taskNoHousehold => 'L\'attività non ha una casa';

  @override
  String get taskUpdated => 'Attività aggiornata!';

  @override
  String get taskDetails => 'Dettagli Attività';

  @override
  String get taskLoadingDetails => 'Caricamento dettagli attività…';

  @override
  String get taskCouldNotLoadDetails =>
      'Impossibile caricare i dettagli dell\'attività.';

  @override
  String get taskDeleteTitle => 'Eliminare l\'attività?';

  @override
  String get taskDeleteMessage =>
      'Questa azione eliminerà permanentemente l\'attività e tutte le sotto-attività.';

  @override
  String get taskStatusCompleted => 'Completata';

  @override
  String get taskReopenTask => 'Riapri Attività';

  @override
  String get taskMarkComplete => 'Segna Completata';

  @override
  String get taskLabelCategory => 'Categoria';

  @override
  String get taskLabelStarts => 'Inizio';

  @override
  String get taskLabelDue => 'Scadenza';

  @override
  String get taskLabelAssignedTo => 'Assegnato a';

  @override
  String get taskSharedBoth => 'Condivisa (entrambi)';

  @override
  String get taskLabelRepeats => 'Ripetizione';

  @override
  String get taskLabelCreatedBy => 'Creato da';

  @override
  String get taskRemoveAttachmentTitle => 'Rimuovere l\'allegato?';

  @override
  String taskRemoveAttachmentMessage(String fileName) {
    return 'Rimuovere \"$fileName\" da questa attività? Il file rimarrà su Google Drive.';
  }

  @override
  String get taskRemove => 'Rimuovi';

  @override
  String get taskAttachFile => 'Allega un file';

  @override
  String get taskAttachAfterSave =>
      'Potrai allegare file dopo aver salvato l\'attività.';

  @override
  String taskPendingAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'file',
      one: 'file',
    );
    return '$count $_temp0 pronto/i per il caricamento';
  }

  @override
  String get taskUploadingAttachments => 'Caricamento allegati…';

  @override
  String get tasksTitle => 'Attività';

  @override
  String get tasksCreateHouseholdFirst => 'Crea prima una casa';

  @override
  String get tasksFilterAll => 'Tutte';

  @override
  String get tasksFilterPending => 'In sospeso';

  @override
  String get tasksFilterDone => 'Fatte';

  @override
  String get tasksAllCategories => 'Tutte le Categorie';

  @override
  String get tasksMore => 'Altro';

  @override
  String get tasksCouldNotLoad => 'Impossibile caricare le attività.';

  @override
  String get tasksNoTasksYet => 'Nessuna attività.\nTocca + per crearne una!';

  @override
  String get tasksAllCaughtUp => 'Tutto in ordine!';

  @override
  String get tasksNoCompletedYet => 'Nessuna attività completata.';

  @override
  String get calendarTitle => 'Calendario';

  @override
  String get calendarActivePlans => 'Piani attivi';

  @override
  String get calendarNewPlan => 'Nuovo Piano';

  @override
  String get calendarLoading => 'Caricamento calendario…';

  @override
  String get calendarCouldNotLoad => 'Impossibile caricare il calendario.';

  @override
  String get calendarNoHousehold => 'Nessuna casa ancora';

  @override
  String get calendarLoadingTasks => 'Caricamento attività…';

  @override
  String get calendarCouldNotLoadTasks => 'Impossibile caricare le attività.';

  @override
  String get attachTitle => 'Allega un File';

  @override
  String get attachPickFile => 'Scegli un file';

  @override
  String get attachPickFileSubtitle =>
      'PDF, documento, foglio di calcolo o qualsiasi file';

  @override
  String get attachTakePhoto => 'Scatta una foto';

  @override
  String get attachTakePhotoSubtitle => 'Apri la fotocamera';

  @override
  String get attachPickGallery => 'Scegli dalla galleria';

  @override
  String get attachPickGallerySubtitle => 'Scegli una foto esistente';

  @override
  String get attachUploading => 'Caricamento file…';

  @override
  String get attachDriveNotSetUp =>
      'Google Drive non è configurato per questa casa. Chiedi all\'amministratore di collegarlo.';

  @override
  String get attachDriveDisabled =>
      'L\'archiviazione su Google Drive è attualmente disabilitata.';

  @override
  String get attachSuccess => 'File allegato con successo!';

  @override
  String attachUploadFailed(String error) {
    return 'Caricamento non riuscito: $error';
  }

  @override
  String get checklistNewChecklist => 'Nuova Lista';

  @override
  String get checklistHint => 'es. Spesa, Essenziali per il Viaggio';

  @override
  String get checklistAddItem => 'Aggiungi Elemento';

  @override
  String get checklistItemName => 'Nome elemento';

  @override
  String get checklistDeleteTitle => 'Eliminare la Lista?';

  @override
  String get checklistDeleteMessage =>
      'Questa azione eliminerà la lista e tutti i suoi elementi.';

  @override
  String get checklistCouldNotCreate => 'Impossibile creare la lista';

  @override
  String get checklistCouldNotAdd => 'Impossibile aggiungere l\'elemento';

  @override
  String get checklistCouldNotUpdate => 'Impossibile aggiornare l\'elemento';

  @override
  String get checklistCouldNotPush =>
      'Impossibile convertire l\'elemento in attività';

  @override
  String get checklistCouldNotDeleteItem => 'Impossibile eliminare l\'elemento';

  @override
  String get checklistCouldNotDeleteList => 'Impossibile eliminare la lista';

  @override
  String checklistAddedAsTask(String title) {
    return '\"$title\" aggiunto come attività';
  }

  @override
  String checklistSectionTitle(int count) {
    return 'Liste · $count';
  }

  @override
  String get checklistNoChecklists => 'Nessuna lista ancora';

  @override
  String get checklistBadgePlan => 'Piano';

  @override
  String get checklistBadgeList => 'Lista';

  @override
  String get checklistPushAsTask => 'Converti in Attività';

  @override
  String checklistCountProgress(int checked, int total) {
    return '$checked/$total';
  }

  @override
  String get planNewPlan => 'Nuovo Piano';

  @override
  String get planStartFromTemplate => 'Inizia da un modello';

  @override
  String get planWeeklyDinnerPlanner => 'Planner Cene Settimanali';

  @override
  String get planWeeklyDinnerDescription =>
      '7 cene per la settimana — una al giorno';

  @override
  String get planOrStartFromScratch => 'Oppure inizia da zero';

  @override
  String get planTitle => 'Titolo piano';

  @override
  String get planTitleHint => 'es. Pasti della Settimana, Viaggio Vacanze';

  @override
  String get planGiveItAName => 'Dagli un nome';

  @override
  String get planTypeWeek => 'Settimana';

  @override
  String get planTypeMonth => 'Mese';

  @override
  String get planTypeCustom => 'Personalizzato';

  @override
  String get planCreatePlan => 'Crea Piano';

  @override
  String planFailedToCreate(String error) {
    return 'Impossibile creare il piano: $error';
  }

  @override
  String get planSelectDates => 'Seleziona le date di inizio e fine';

  @override
  String get planConfirm => 'Conferma';

  @override
  String planDaysCount(int count) {
    return '$count giorni';
  }

  @override
  String planStartsDate(String date) {
    return 'Inizio: $date';
  }

  @override
  String planTemplateEntries(String type, int count) {
    return 'Piano $type • $count voci';
  }

  @override
  String get planLoadingPlan => 'Caricamento piano…';

  @override
  String get planCouldNotLoad => 'Impossibile caricare il piano.';

  @override
  String get planInvalidMissingDates => 'Piano non valido: date mancanti';

  @override
  String get planInvalidUnreadableDates =>
      'Piano non valido: date non leggibili';

  @override
  String get planSaveAsTemplate => 'Salva come Modello';

  @override
  String get planTemplateName => 'Nome modello';

  @override
  String get planFinalise => 'Finalizza';

  @override
  String get planFinalisedChip => 'Finalizzato';

  @override
  String get planTapToAdd =>
      'Tocca + per aggiungere pasti, attività o qualsiasi cosa tu stia pianificando.';

  @override
  String get planChecklist => 'Lista';

  @override
  String get planAddItemHint => 'Aggiungi elemento...';

  @override
  String get planNoItemsYet =>
      'Nessun elemento ancora. Aggiungi cose da comprare o fare.';

  @override
  String planTemplateSaved(String name) {
    return 'Modello \"$name\" salvato!';
  }

  @override
  String planFailedToSaveTemplate(String error) {
    return 'Impossibile salvare il modello: $error';
  }

  @override
  String planFailedToAddItem(String error) {
    return 'Impossibile aggiungere l\'elemento: $error';
  }

  @override
  String get planFinalisePlan => 'Finalizza Piano';

  @override
  String get planLoadingEntries => 'Caricamento voci del piano…';

  @override
  String get planPushToCalendar => 'Inviare al Calendario?';

  @override
  String planPushSummary(int tasks, int notes) {
    return '$tasks attività e $notes nota/e verranno create.\n\nLe voci saltate non verranno aggiunte al calendario.';
  }

  @override
  String get planPushToCalendarButton => 'Invia al Calendario';

  @override
  String get planFinalisedSuccess => 'Piano Finalizzato!';

  @override
  String get planEntriesPushed =>
      'Le tue voci sono state inviate al calendario.';

  @override
  String get planViewCalendar => 'Vedi Calendario';

  @override
  String planFailedToFinalise(String error) {
    return 'Impossibile finalizzare: $error';
  }

  @override
  String get planNoEntriesToFinalise => 'Nessuna voce da finalizzare.';

  @override
  String get planGoBack => 'Torna Indietro';

  @override
  String get planInfoBanner =>
      'Scegli cosa diventa ogni voce nel tuo calendario. Le attività possono essere assegnate e completate. Le note sono promemoria leggeri.';

  @override
  String get planActionTask => 'Attività';

  @override
  String get planActionNote => 'Nota';

  @override
  String get planActionSkip => 'Salta';

  @override
  String get planLoadingDay => 'Caricamento voci del giorno…';

  @override
  String get planCouldNotLoadDay => 'Impossibile caricare le voci del giorno.';

  @override
  String planFailedToAdd(String error) {
    return 'Impossibile aggiungere: $error';
  }

  @override
  String planFailedToDelete(String error) {
    return 'Impossibile eliminare: $error';
  }

  @override
  String get planNewLabel => 'Nuova Etichetta';

  @override
  String get planLabelHint => 'es. Dessert, Gita';

  @override
  String get planEditEntry => 'Modifica Voce';

  @override
  String get planWhatsPlanned => 'Cosa è previsto?';

  @override
  String get planCustomLabel => 'Personalizzato';

  @override
  String planWhatsForLabel(String label) {
    return 'Cosa c\'è per $label?';
  }

  @override
  String planAddNeedsFor(String entry) {
    return 'Aggiungi necessità per \"$entry\"';
  }

  @override
  String get planNeedsHint => 'es. pasta, carne macinata, pomodori';

  @override
  String get planNeedsHelper => 'Separa con virgole';

  @override
  String get planAddToList => 'Aggiungi alla Lista';

  @override
  String planItemsAddedToChecklist(int count) {
    return '$count elemento/i aggiunto/i alla lista';
  }

  @override
  String planFailedToUpdate(String error) {
    return 'Impossibile aggiornare: $error';
  }

  @override
  String get planAddToChecklist => 'Aggiungi alla lista';

  @override
  String get planEdit => 'Modifica';

  @override
  String get planLabelDinner => 'Cena';

  @override
  String get planLabelBreakfast => 'Colazione';

  @override
  String get planLabelLunch => 'Pranzo';

  @override
  String get planLabelSnack => 'Merenda';

  @override
  String get planLabelActivity => 'Attività';

  @override
  String get planLabelTransport => 'Trasporto';

  @override
  String get planLabelAccommodation => 'Alloggio';

  @override
  String get householdCreateTitle => 'Crea Casa';

  @override
  String get householdNameYour => 'Dai un nome alla tua casa';

  @override
  String get householdNameSubtitle =>
      'Questo è ciò che tu e il tuo partner vedrete.\nPuoi cambiarlo in qualsiasi momento.';

  @override
  String get householdNameLabel => 'Nome della casa';

  @override
  String get householdNameHint => 'es. Casa Celis';

  @override
  String get householdEnterName => 'Inserisci un nome per la tua casa';

  @override
  String get householdNameMinLength => 'Il nome deve avere almeno 2 caratteri';

  @override
  String get householdCreateButton => 'Crea Casa';

  @override
  String get householdCreated => 'Casa creata! Benvenuto a casa.';

  @override
  String get householdCreateFailed => 'Impossibile creare la casa. Riprova.';

  @override
  String get householdTitle => 'Casa';

  @override
  String get householdLoading => 'Caricamento casa…';

  @override
  String get householdCouldNotLoad => 'Impossibile caricare la casa.';

  @override
  String get householdNotFound => 'Nessuna casa trovata.';

  @override
  String get householdMyHousehold => 'La Mia Casa';

  @override
  String get householdRoleAdmin => 'Sei l\'amministratore';

  @override
  String get householdRoleMember => 'Sei un membro';

  @override
  String get householdMembers => 'Membri';

  @override
  String get householdLoadingMembers => 'Caricamento membri…';

  @override
  String get householdCouldNotLoadMembers =>
      'Impossibile caricare i membri. Scorri verso il basso per riprovare.';

  @override
  String get householdYouSuffix => '(Tu)';

  @override
  String get householdRoleAdminLabel => 'Amministratore';

  @override
  String get householdRoleMemberLabel => 'Membro';

  @override
  String get householdStorageSection => 'Archiviazione';

  @override
  String get householdFileStorage => 'Archiviazione File';

  @override
  String get householdFileStorageSubtitle =>
      'Allega file alle attività tramite Google Drive';

  @override
  String get householdInvitePartner => 'Invita Partner';

  @override
  String get householdInviteMessage =>
      'Invia un invito all\'email del tuo partner. Verrà aggiunto alla tua casa quando si registra o accede.';

  @override
  String get householdPartnerEmail => 'Email del partner';

  @override
  String get householdPartnerEmailHint => 'partner@esempio.com';

  @override
  String get householdInvite => 'Invita';

  @override
  String get householdInviteValidEmail =>
      'Inserisci un indirizzo email valido.';

  @override
  String householdInviteSent(String email) {
    return 'Invito inviato a $email! Vedranno la casa quando si registrano.';
  }

  @override
  String get householdInviteFailed => 'Impossibile inviare l\'invito. Riprova.';

  @override
  String get driveTitle => 'Archiviazione File';

  @override
  String get driveConnected => 'Google Drive Collegato';

  @override
  String get driveConnect => 'Collega Google Drive';

  @override
  String get driveConnectedSubtitle =>
      'I file della casa sono archiviati nel tuo Google Drive.';

  @override
  String get driveConnectSubtitle =>
      'Archivia foto, documenti e altri file insieme alle attività della tua casa.';

  @override
  String get driveHowItWorks => 'COME FUNZIONA';

  @override
  String get driveInfoFolder =>
      'Viene creata una cartella \"Pacelli\" nel tuo Google Drive.';

  @override
  String get driveInfoAttach =>
      'Allega foto, PDF o fogli di calcolo a qualsiasi attività.';

  @override
  String get driveInfoMembers =>
      'I membri della casa possono visualizzare i file allegati tramite link.';

  @override
  String get driveInfoQuota =>
      'I file usano il TUO spazio Google Drive — nessun costo aggiuntivo.';

  @override
  String get drivePrivacyNote =>
      'Pacelli accede solo ai file che crea. Non può vedere o modificare gli altri file del tuo Drive.';

  @override
  String get driveStorageActive => 'L\'archiviazione Drive è attiva';

  @override
  String get driveCanAttachNow => 'Ora puoi allegare file alle attività.';

  @override
  String get drivePacelliFolder => 'Cartella Pacelli su Google Drive';

  @override
  String get driveDisconnectTitle => 'Scollegare Drive?';

  @override
  String get driveDisconnectMessage =>
      'Gli allegati esistenti saranno ancora accessibili tramite i loro link, ma non potrai caricare nuovi file finché non ricolleghi.';

  @override
  String get driveDisconnect => 'Scollega';

  @override
  String get driveConnectButton => 'Collega Google Drive';

  @override
  String get driveDisconnectButton => 'Scollega Google Drive';

  @override
  String get driveAdminOnly =>
      'Solo l\'amministratore della casa può collegare o scollegare l\'archiviazione Google Drive.';

  @override
  String get driveAccessNotGranted =>
      'L\'accesso a Drive non è stato concesso. Riprova.';

  @override
  String get driveConnectedSuccess => 'Google Drive collegato con successo!';

  @override
  String driveConnectFailed(String error) {
    return 'Impossibile collegare Google Drive: $error';
  }

  @override
  String get driveDisconnected => 'Google Drive scollegato.';

  @override
  String driveDisconnectFailed(String error) {
    return 'Impossibile scollegare: $error';
  }

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsHousehold => 'Casa';

  @override
  String get settingsHouseholdSubtitle => 'Gestisci casa e membri';

  @override
  String get settingsNotifications => 'Notifiche';

  @override
  String get settingsNotificationsSubtitle => 'Promemoria e avvisi';

  @override
  String get settingsPrivacy => 'Privacy e Crittografia';

  @override
  String get settingsPrivacySubtitle => 'Come sono protetti i tuoi dati';

  @override
  String get settingsDataStorage => 'Archiviazione Dati';

  @override
  String get settingsAppearance => 'Aspetto';

  @override
  String get settingsAppearanceSubtitle => 'Tema e visualizzazione';

  @override
  String get settingsAbout => 'Informazioni su Pacelli';

  @override
  String get settingsAboutVersion => 'Versione 1.0.0';

  @override
  String get settingsSignOut => 'Esci';

  @override
  String get settingsSignOutFailed => 'Impossibile uscire. Riprova.';

  @override
  String settingsComingSoon(String feature) {
    return 'Le impostazioni di $feature arriveranno in un prossimo aggiornamento. Resta sintonizzato!';
  }

  @override
  String get settingsAboutDescription =>
      'Pacelli aiuta la tua casa a restare organizzata — attività, piani, liste e altro, tutto in un unico posto.';

  @override
  String get settingsDataStorageTitle => 'Archiviazione Dati';

  @override
  String get settingsCurrentBackend => 'Backend attuale:';

  @override
  String get settingsBackendLocal => 'Su Questo Dispositivo (SQLite)';

  @override
  String get settingsBackendCloud => 'Sincronizzazione Cloud (Firebase)';

  @override
  String get settingsEndToEndEncrypted => 'Crittografia end-to-end';

  @override
  String get settingsSwitchBackend =>
      'Per cambiare backend, tocca \"Cambia\" sotto. Nota: i dati esistenti non verranno migrati automaticamente.';

  @override
  String get settingsDangerZone => 'ZONA PERICOLOSA';

  @override
  String get settingsBurnAllData => 'Distruggi Tutti i Miei Dati';

  @override
  String get settingsBurnExplanation =>
      'Elimina permanentemente tutti i tuoi dati, le impostazioni salvate e disconnettiti. Questa azione non può essere annullata.';

  @override
  String get settingsBurnTitle => 'Distruggere Tutti i Dati?';

  @override
  String get settingsBurnWillDelete => 'Questo eliminerà permanentemente:';

  @override
  String get settingsBurnTasks => 'Tutte le attività, piani e liste';

  @override
  String get settingsBurnCategories => 'Tutte le categorie e impostazioni';

  @override
  String get settingsBurnLocalDb => 'Database locale (se utilizzato)';

  @override
  String get settingsBurnCloudData =>
      'Dati cloud (se usi Sincronizzazione Cloud)';

  @override
  String get settingsBurnKeys => 'Chiavi di crittografia e preferenze salvate';

  @override
  String get settingsBurnCredentials =>
      'Il tuo nome utente e password (disconnessione completa)';

  @override
  String get settingsBurnSession =>
      'La tua sessione — dovrai accedere di nuovo';

  @override
  String get settingsBurnIrreversible =>
      'Questa azione è irreversibile. Non c\'è modo di recuperare i tuoi dati dopo.';

  @override
  String get settingsBurnEverything => 'Distruggi Tutto';

  @override
  String get privacyTitle => 'Privacy e Crittografia';

  @override
  String get privacyE2ETitle => 'Crittografia End-to-End';

  @override
  String get privacyE2ESubtitle =>
      'Crittografia AES-256 — lo stesso standard usato da banche e governi.';

  @override
  String get privacyHowProtected => 'Come sono protetti i tuoi dati';

  @override
  String get privacyAllContent =>
      'Tutti i tuoi contenuti personali — nomi delle attività, descrizioni, titoli dei piani, elementi delle liste, il nome della tua casa — sono crittografati end-to-end prima di lasciare il tuo dispositivo.';

  @override
  String get privacyOnlyYou =>
      'Solo tu e i membri della tua casa possono leggere i tuoi dati. Nemmeno gli sviluppatori dell\'app possono vederli.';

  @override
  String get privacyWhatEncrypted => 'Cosa è crittografato';

  @override
  String get privacyTaskTitles => 'Titoli e descrizioni delle attività';

  @override
  String get privacySubtaskTitles => 'Titoli delle sotto-attività';

  @override
  String get privacyChecklistTitles => 'Titoli delle liste e degli elementi';

  @override
  String get privacyPlanTitles =>
      'Titoli, voci, etichette e descrizioni dei piani';

  @override
  String get privacyCategoryNames => 'Nomi delle categorie';

  @override
  String get privacyHouseholdName => 'Nome della casa';

  @override
  String get privacyDisplayName => 'Il tuo nome visualizzato';

  @override
  String get privacyAttachmentNames => 'Nomi e descrizioni degli allegati';

  @override
  String get privacyAttachmentMetadata =>
      'Metadati degli allegati (tipo di file, link, miniature)';

  @override
  String get privacyWhatNotEncrypted => 'Cosa non è crittografato';

  @override
  String get privacyTaskStatus =>
      'Stato delle attività (in sospeso, completata, ecc.)';

  @override
  String get privacyPriorityLevels =>
      'Livelli di priorità (bassa, media, alta, urgente)';

  @override
  String get privacyDueDates => 'Date di scadenza e timestamp';

  @override
  String get privacyCheckedStatus =>
      'Se gli elementi sono spuntati o completati';

  @override
  String get privacySortOrder =>
      'Ordine di visualizzazione e impostazioni di visualizzazione';

  @override
  String get privacyCategoryIcons => 'Icone e colori delle categorie';

  @override
  String get privacyFileAttachments => 'Allegati file (Google Drive)';

  @override
  String get privacyDriveExplanation =>
      'I file che alleghi alle attività sono archiviati nel Google Drive del proprietario della casa, in una cartella dedicata \"Pacelli\". I nomi e le descrizioni dei file sono crittografati nel database di Pacelli, ma i file effettivi su Google Drive sono protetti dalla sicurezza di Google — non dalla crittografia E2E di Pacelli.';

  @override
  String get privacyDriveAccess =>
      'I membri della casa accedono ai file tramite link di sola visualizzazione condivisibili. I file sono archiviati utilizzando lo spazio Google Drive del proprietario — nessun costo aggiuntivo per l\'app.';

  @override
  String get privacyWhyNotEncrypted =>
      'Perché alcuni campi non sono crittografati';

  @override
  String get privacyWhyExplanation =>
      'Questi campi strutturali sono necessari per filtrare, ordinare e organizzare i tuoi dati sul server. Non contengono informazioni personali — sono etichette come \"completata\" o \"priorità alta\", non i tuoi contenuti effettivi.';

  @override
  String get privacyYourControl => 'I tuoi dati, il tuo controllo';

  @override
  String get privacyDeleteAll =>
      'Puoi eliminare TUTTI i tuoi dati in qualsiasi momento usando \"Distruggi Tutti i Miei Dati\" nelle Impostazioni. Quando elimini i tuoi dati, il contenuto crittografato viene rimosso permanentemente dai nostri server.';

  @override
  String get privacyKeyGeneration =>
      'La tua chiave di crittografia viene generata sul tuo dispositivo e non viene mai archiviata in forma leggibile sul server. Ogni membro della casa riceve la propria copia crittografata della chiave condivisa.';

  @override
  String get storageWhereDataLive => 'Dove devono vivere i tuoi dati?';

  @override
  String get storageSubtitle =>
      'Le tue attività, piani e liste sono tuoi. Scegli dove conservarli.';

  @override
  String get storageOnDevice => 'Su Questo Dispositivo';

  @override
  String get storageOnDeviceDescription =>
      'I dati restano sul tuo telefono. Nessun cloud, nessuna sincronizzazione, massima privacy.';

  @override
  String get storageCloudSync => 'Sincronizzazione Cloud';

  @override
  String get storageCloudSyncDescription =>
      'Sincronizzazione multi-dispositivo in tempo reale. Tutti i tuoi contenuti sono crittografati end-to-end.';

  @override
  String get storageRecommended => 'Consigliato';

  @override
  String get storagePrivacyNote =>
      'La Sincronizzazione Cloud usa crittografia AES-256 end-to-end. I tuoi contenuti personali (nomi attività, descrizioni, elementi lista) sono crittografati sul tuo dispositivo prima di uscire. Nemmeno noi possiamo leggerli.';

  @override
  String storageFailedLocal(String error) {
    return 'Impossibile configurare l\'archiviazione locale: $error';
  }

  @override
  String storageFailedCloud(String error) {
    return 'Impossibile configurare la sincronizzazione cloud: $error';
  }

  @override
  String get errorDefault => 'Qualcosa è andato storto.\nRiprova.';

  @override
  String get taskRecurrenceDaily => 'Giornaliero';

  @override
  String get taskRecurrenceWeekly => 'Settimanale';

  @override
  String get taskRecurrenceBiweekly => 'Ogni 2 settimane';

  @override
  String get taskRecurrenceMonthly => 'Mensile';

  @override
  String taskSubtaskProgress(int completed, int total) {
    return '$completed/$total';
  }

  @override
  String get taskNew => 'Nuovo';

  @override
  String get commonNew => 'Nuovo';

  @override
  String get commonOK => 'OK';

  @override
  String get taskAddSubtask => 'Aggiungi una sotto-attività...';

  @override
  String get taskDescription => 'Descrizione (facoltativa)';

  @override
  String get taskLabelAssignTo => 'Assegna a';

  @override
  String get taskLabelPriority => 'Priorità';

  @override
  String get taskLabelRepeat => 'Ripeti';

  @override
  String get taskRecurrenceNone => 'Mai';

  @override
  String get taskUnassigned => 'Non assegnato';

  @override
  String get tasksFailedToLoadHousehold => 'Impossibile caricare la casa';

  @override
  String get tasksLoadingHousehold => 'Caricamento casa…';

  @override
  String get navHome => 'Home';

  @override
  String get navTasks => 'Attività';

  @override
  String get navCalendar => 'Calendario';

  @override
  String get navSettings => 'Impostazioni';

  @override
  String get priorityUrgent => 'Urgente';

  @override
  String get priorityHigh => 'Alta';

  @override
  String get priorityMedium => 'Media';

  @override
  String get priorityLow => 'Bassa';

  @override
  String get priorityNone => 'Nessuna';

  @override
  String get recurrenceDaily => 'Giornaliero';

  @override
  String get recurrenceWeekly => 'Settimanale';

  @override
  String get recurrenceEveryTwoWeeks => 'Ogni 2 settimane';

  @override
  String get recurrenceMonthly => 'Mensile';

  @override
  String get recurrenceNever => 'Mai';

  @override
  String calendarTasksSectionTitle(String dayLabel, int count) {
    return 'Attività · $dayLabel · $count';
  }

  @override
  String get calendarNoTasksOnDay => 'Nessuna attività in questo giorno';

  @override
  String calendarPlansSectionTitle(int count) {
    return 'Piani · $count';
  }

  @override
  String get calendarNoDraftPlans => 'Nessun piano in bozza';

  @override
  String calendarPlanEntries(int count) {
    return '$count voci';
  }

  @override
  String calendarChecklistItems(int count) {
    return '$count elementi della lista';
  }

  @override
  String get settingsBurnDriveWarning =>
      'Nota — questo non eliminerà la cartella Pacelli in Google Drive né i file sul tuo dispositivo. Dovrai rimuoverli manualmente se lo desideri.';

  @override
  String get settingsBurnDriveWarningShort =>
      'I file in Google Drive o nello spazio locale devono essere eliminati manualmente.';

  @override
  String get burnStatusBurning => 'Bruciando i tuoi dati...';

  @override
  String get burnStatusDestroying => 'Distruggendo i tuoi dati...';

  @override
  String get burnStatusClearingLocal =>
      'Cancellando l\'archiviazione locale...';

  @override
  String get burnStatusClearingKeys =>
      'Eliminando le chiavi di crittografia...';

  @override
  String get burnStatusSigningOut => 'Disconnessione in corso...';

  @override
  String get burnStatusRemovingSettings =>
      'Rimuovendo le impostazioni salvate...';

  @override
  String get burnStatusComplete => 'Tutti i dati sono stati distrutti.';

  @override
  String get burnStatusError => 'Qualcosa è andato storto. Riprova.';

  @override
  String get burnPasswordTitle => 'Conferma eliminazione account';

  @override
  String get burnPasswordMessage =>
      'Per eliminare definitivamente il tuo account e tutti i dati, inserisci la tua password.';

  @override
  String get burnPasswordHint => 'Password';

  @override
  String get burnPasswordConfirm => 'Elimina tutto';

  @override
  String get burnPasswordError => 'Password errata. Riprova.';

  @override
  String get appearanceTitle => 'Aspetto';

  @override
  String get appearanceThemeMode => 'Modalità tema';

  @override
  String get appearanceThemeModeSubtitle =>
      'Scegli chiaro, scuro o segui le impostazioni del dispositivo';

  @override
  String get appearanceModeSystem => 'Auto';

  @override
  String get appearanceModeLight => 'Chiaro';

  @override
  String get appearanceModeDark => 'Scuro';

  @override
  String get appearanceColorScheme => 'Schema di colori';

  @override
  String get appearanceColorSchemeSubtitle => 'Scegli una palette che ti piace';

  @override
  String get appearanceSchemePacelli => 'Pacelli';

  @override
  String get appearanceSchemePacelliDesc => 'Verde salvia e terracotta';

  @override
  String get appearanceSchemeClaude => 'Claude';

  @override
  String get appearanceSchemeClaudeDesc => 'Viola caldo e corallo';

  @override
  String get appearanceSchemeGemini => 'Gemini';

  @override
  String get appearanceSchemeGeminiDesc => 'Blu oceano e corallo';

  @override
  String attachCount(int count) {
    return 'Allegati ($count)';
  }

  @override
  String get attachInvalidLink => 'Link non valido.';

  @override
  String get attachCouldNotOpen => 'Impossibile aprire il file.';

  @override
  String get attachRemoveTooltip => 'Rimuovi allegato';

  @override
  String get planAttachFile => 'Allega un file';

  @override
  String get planRemoveAttachmentTitle => 'Rimuovere l\'allegato?';

  @override
  String planRemoveAttachmentMessage(String fileName) {
    return 'Rimuovere \"$fileName\" da questa voce? Il file rimarrà in Google Drive.';
  }

  @override
  String planAttachmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'file',
      one: 'file',
    );
    return '$count $_temp0';
  }

  @override
  String get notifTitle => 'Notifiche';

  @override
  String get notifEnable => 'Attiva notifiche';

  @override
  String get notifEnableSubtitle =>
      'Ricevi promemoria quando le attività scadono';

  @override
  String get notifTimingTitle => 'Momento del promemoria';

  @override
  String get notifTimingSubtitle =>
      'Quando vuoi essere avvisato delle attività in scadenza?';

  @override
  String get notifTimingAtDue => 'Alla scadenza';

  @override
  String get notifTimingAtDueDesc =>
      'Notifica esattamente quando l\'attività scade';

  @override
  String get notifTimingOneHour => '1 ora prima';

  @override
  String get notifTimingOneHourDesc => 'Ricevi un avviso un\'ora prima';

  @override
  String get notifTimingOneDay => '1 giorno prima';

  @override
  String get notifTimingOneDayDesc => 'Promemoria alle 9 del giorno prima';

  @override
  String get notifInfoNote =>
      'Le notifiche vengono inviate localmente su questo dispositivo. Funzionano anche con l\'app chiusa.';

  @override
  String get settingsImportExport => 'Importa / Esporta';

  @override
  String get settingsImportExportSubtitle =>
      'Backup e ripristino dei tuoi dati';

  @override
  String get ieTitle => 'Importa / Esporta';

  @override
  String get ieExportSection => 'ESPORTA';

  @override
  String get ieExportJson => 'Esporta come JSON';

  @override
  String get ieExportJsonDesc =>
      'Backup completo di attività, liste, piani e categorie';

  @override
  String get ieExportCsv => 'Esporta attività come CSV';

  @override
  String get ieExportCsvDesc =>
      'Lista di attività in formato foglio di calcolo';

  @override
  String get ieExportSuccess => 'Esportazione salvata con successo!';

  @override
  String ieExportFailed(String error) {
    return 'Errore nell\'esportazione: $error';
  }

  @override
  String ieLastExport(String date) {
    return 'Ultima esportazione: $date';
  }

  @override
  String get ieImportSection => 'IMPORTA';

  @override
  String get ieImportButton => 'Importa da backup';

  @override
  String get ieImportDesc => 'Ripristina i dati da un file JSON di Pacelli';

  @override
  String get ieImportReading => 'Lettura del file...';

  @override
  String ieImportInvalid(String error) {
    return 'File di backup non valido: $error';
  }

  @override
  String get ieImportConfirmTitle => 'Importare i dati?';

  @override
  String get ieImportConfirmMessage =>
      'Questo aggiungerà i dati del backup alla tua famiglia attuale. I dati esistenti non verranno eliminati.';

  @override
  String ieImportSuccess(int created, int skipped) {
    return 'Importazione completata! $created elementi creati, $skipped saltati.';
  }

  @override
  String ieImportFailed(String error) {
    return 'Errore nell\'importazione: $error';
  }

  @override
  String get ieInfoNote =>
      'I file esportati vengono salvati in testo semplice. Se i tuoi dati sono crittografati nel cloud, verranno decrittografati per l\'esportazione.';
}
