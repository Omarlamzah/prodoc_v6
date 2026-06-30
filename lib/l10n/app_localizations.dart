import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'NextPital Mobile App'**
  String get appTitle;

  /// Welcome message
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// Login button text
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Logout button text
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Dashboard screen title
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// Patients screen title
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get patients;

  /// Appointments screen title
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointments;

  /// Medical records screen title
  ///
  /// In en, this message translates to:
  /// **'Medical Records'**
  String get medicalRecords;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// French language option
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// Arabic language option
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// Save button text
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Delete button text
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Edit button text
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Add button text
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Search placeholder text
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Loading indicator text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Error message title
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Success message title
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// Message when no data is available
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noData;

  /// Main section header
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get main;

  /// Overview subtitle
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// Quick actions FAB label
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// Create appointment button
  ///
  /// In en, this message translates to:
  /// **'Create Appointment'**
  String get createAppointment;

  /// New appointment subtitle
  ///
  /// In en, this message translates to:
  /// **'New appointment'**
  String get newAppointment;

  /// Create prescription button
  ///
  /// In en, this message translates to:
  /// **'Create Prescription'**
  String get createPrescription;

  /// New prescription subtitle
  ///
  /// In en, this message translates to:
  /// **'New prescription'**
  String get newPrescription;

  /// New invoice button
  ///
  /// In en, this message translates to:
  /// **'New Invoice'**
  String get newInvoice;

  /// Create invoice subtitle
  ///
  /// In en, this message translates to:
  /// **'Create invoice'**
  String get createInvoice;

  /// Create medical record button
  ///
  /// In en, this message translates to:
  /// **'Create Medical Record'**
  String get createMedicalRecord;

  /// New record subtitle
  ///
  /// In en, this message translates to:
  /// **'New record'**
  String get newRecord;

  /// Calendar section header
  ///
  /// In en, this message translates to:
  /// **'Calendar & Appointments'**
  String get calendarAndAppointments;

  /// Calendar button
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @allServices.
  ///
  /// In en, this message translates to:
  /// **'All Services'**
  String get allServices;

  /// Calendar view subtitle
  ///
  /// In en, this message translates to:
  /// **'Calendar view'**
  String get calendarView;

  /// All appointments subtitle
  ///
  /// In en, this message translates to:
  /// **'All appointments'**
  String get allAppointments;

  /// Appointment requests screen title
  ///
  /// In en, this message translates to:
  /// **'Appointment Requests'**
  String get appointmentRequests;

  /// Manage pending requests subtitle
  ///
  /// In en, this message translates to:
  /// **'Manage pending requests'**
  String get managePendingRequests;

  /// Waiting room button
  ///
  /// In en, this message translates to:
  /// **'Waiting Room'**
  String get waitingRoom;

  /// Waiting room display subtitle
  ///
  /// In en, this message translates to:
  /// **'Waiting room display'**
  String get waitingRoomDisplay;

  /// Management section header
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get management;

  /// Patient list subtitle
  ///
  /// In en, this message translates to:
  /// **'Patient list'**
  String get patientList;

  /// Doctors button
  ///
  /// In en, this message translates to:
  /// **'Doctors'**
  String get doctors;

  /// Manage doctors subtitle
  ///
  /// In en, this message translates to:
  /// **'Manage doctors'**
  String get manageDoctors;

  /// Medications label
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get medications;

  /// Manage medications subtitle
  ///
  /// In en, this message translates to:
  /// **'Manage medications'**
  String get manageMedications;

  /// Reports button
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// View reports subtitle
  ///
  /// In en, this message translates to:
  /// **'View reports'**
  String get viewReports;

  /// Invoices button
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoices;

  /// Invoice management subtitle
  ///
  /// In en, this message translates to:
  /// **'Invoice management'**
  String get invoiceManagement;

  /// My prescriptions button
  ///
  /// In en, this message translates to:
  /// **'My Prescriptions'**
  String get myPrescriptions;

  /// My prescriptions subtitle
  ///
  /// In en, this message translates to:
  /// **'My prescriptions'**
  String get myPrescriptionsSubtitle;

  /// Doctor tools section header
  ///
  /// In en, this message translates to:
  /// **'Doctor Tools'**
  String get doctorTools;

  /// Patient history button
  ///
  /// In en, this message translates to:
  /// **'Patient History'**
  String get patientHistory;

  /// Medical history subtitle
  ///
  /// In en, this message translates to:
  /// **'Medical history'**
  String get medicalHistory;

  /// Diagnosis label
  ///
  /// In en, this message translates to:
  /// **'Diagnosis'**
  String get diagnosis;

  /// Diagnostic tools subtitle
  ///
  /// In en, this message translates to:
  /// **'Diagnostic tools'**
  String get diagnosticTools;

  /// Lab results button
  ///
  /// In en, this message translates to:
  /// **'Lab Results'**
  String get labResults;

  /// Analyses and tests subtitle
  ///
  /// In en, this message translates to:
  /// **'Analyses and tests'**
  String get analysesAndTests;

  /// Medical reports button
  ///
  /// In en, this message translates to:
  /// **'Medical Reports'**
  String get medicalReports;

  /// Reports and statistics subtitle
  ///
  /// In en, this message translates to:
  /// **'Reports and statistics'**
  String get reportsAndStatistics;

  /// Clinical notes button
  ///
  /// In en, this message translates to:
  /// **'Clinical Notes'**
  String get clinicalNotes;

  /// Notes and observations subtitle
  ///
  /// In en, this message translates to:
  /// **'Notes and observations'**
  String get notesAndObservations;

  /// Vaccinations button
  ///
  /// In en, this message translates to:
  /// **'Vaccinations'**
  String get vaccinations;

  /// Vaccination management subtitle
  ///
  /// In en, this message translates to:
  /// **'Vaccination management'**
  String get vaccinationManagement;

  /// Emergencies button
  ///
  /// In en, this message translates to:
  /// **'Emergencies'**
  String get emergencies;

  /// Emergency cases subtitle
  ///
  /// In en, this message translates to:
  /// **'Emergency cases'**
  String get emergencyCases;

  /// Consultations button
  ///
  /// In en, this message translates to:
  /// **'Consultations'**
  String get consultations;

  /// My consultations subtitle
  ///
  /// In en, this message translates to:
  /// **'My consultations'**
  String get myConsultations;

  /// Help and support button
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpAndSupport;

  /// Need help subtitle
  ///
  /// In en, this message translates to:
  /// **'Need help?'**
  String get needHelp;

  /// Rate app button
  ///
  /// In en, this message translates to:
  /// **'Rate the app'**
  String get rateApp;

  /// Rate on Play Store subtitle
  ///
  /// In en, this message translates to:
  /// **'Rate on Play Store'**
  String get rateOnPlayStore;

  /// Organization label
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get organization;

  /// Change button
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// Forgot password link
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// Remember me checkbox
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// Don't have account text
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// Register button
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Please enter email validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterEmail;

  /// Today time range
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// This week time range
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// This month time range
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// This year time range
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get thisYear;

  /// All time range
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// Configuration subtitle
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get configuration;

  /// Services button
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// Manage services subtitle
  ///
  /// In en, this message translates to:
  /// **'Manage services'**
  String get manageServices;

  /// All records subtitle
  ///
  /// In en, this message translates to:
  /// **'All records'**
  String get allRecords;

  /// Hospital reports subtitle
  ///
  /// In en, this message translates to:
  /// **'Hospital reports'**
  String get hospitalReports;

  /// Medical practice management subtitle
  ///
  /// In en, this message translates to:
  /// **'Medical Practice Management'**
  String get medicalPracticeManagement;

  /// Sign in to continue message
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

  /// Email address label
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// Please enter valid email validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterValidEmail;

  /// Please enter password validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterPassword;

  /// Password length validation message
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMustBeAtLeast;

  /// Reset password button
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// Back to login button
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;

  /// Send reset link button
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// Day time range
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// Week time range
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// Month time range
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// Total patients stat card
  ///
  /// In en, this message translates to:
  /// **'Total Patients'**
  String get totalPatients;

  /// Total appointments stat card
  ///
  /// In en, this message translates to:
  /// **'Total Appointments'**
  String get totalAppointments;

  /// Pending invoices stat card
  ///
  /// In en, this message translates to:
  /// **'Pending Invoices'**
  String get pendingInvoices;

  /// Requires action subtitle
  ///
  /// In en, this message translates to:
  /// **'Requires action'**
  String get requiresAction;

  /// Urgent cases label
  ///
  /// In en, this message translates to:
  /// **'Urgent Cases'**
  String get urgentCases;

  /// High priority cases subtitle
  ///
  /// In en, this message translates to:
  /// **'High priority cases'**
  String get highPriorityCases;

  /// Total prescriptions stat card
  ///
  /// In en, this message translates to:
  /// **'Total Prescriptions'**
  String get totalPrescriptions;

  /// Active status
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// Expired status
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// Patients waiting subtitle
  ///
  /// In en, this message translates to:
  /// **'Patients waiting'**
  String get patientsWaiting;

  /// Analysis overview section title
  ///
  /// In en, this message translates to:
  /// **'Analysis Overview'**
  String get analysisOverview;

  /// Appointment status chart title
  ///
  /// In en, this message translates to:
  /// **'Appointment Status'**
  String get appointmentStatus;

  /// User default name
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// Hello greeting
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get hello;

  /// Review dialog title
  ///
  /// In en, this message translates to:
  /// **'Hello! 👋'**
  String get reviewDialogTitle;

  /// Review dialog message
  ///
  /// In en, this message translates to:
  /// **'You\'ve been using ProDoc for a while now. Would you be ready to leave us a review on the Play Store? It would help us a lot!'**
  String get reviewDialogMessage;

  /// Rate now button
  ///
  /// In en, this message translates to:
  /// **'Rate now ⭐'**
  String get rateNow;

  /// Maybe later button
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get maybeLater;

  /// Cannot open Play Store error message
  ///
  /// In en, this message translates to:
  /// **'Unable to open Play Store. Please try again later.'**
  String get cannotOpenPlayStore;

  /// Monthly appointments chart title
  ///
  /// In en, this message translates to:
  /// **'Monthly Appointments'**
  String get monthlyAppointments;

  /// Prescriptions chart title
  ///
  /// In en, this message translates to:
  /// **'Prescriptions'**
  String get prescriptions;

  /// Patient details screen title
  ///
  /// In en, this message translates to:
  /// **'Patient Details'**
  String get patientDetails;

  /// Information tab label
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get information;

  /// Records tab label
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get records;

  /// Lab tests tab label
  ///
  /// In en, this message translates to:
  /// **'Lab Tests'**
  String get labTests;

  /// Certificates tab label
  ///
  /// In en, this message translates to:
  /// **'Certificates'**
  String get certificates;

  /// Search type dropdown label
  ///
  /// In en, this message translates to:
  /// **'Search Type'**
  String get searchType;

  /// Filters and sort section title
  ///
  /// In en, this message translates to:
  /// **'Filters and Sort'**
  String get filtersAndSort;

  /// Sort by dropdown label
  ///
  /// In en, this message translates to:
  /// **'Sort By'**
  String get sortBy;

  /// Order dropdown label
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get order;

  /// Ascending sort order
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get ascending;

  /// Descending sort order
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get descending;

  /// Name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// Gender field label
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// Birth date field label
  ///
  /// In en, this message translates to:
  /// **'Birth Date'**
  String get birthDate;

  /// Blood type field label
  ///
  /// In en, this message translates to:
  /// **'Blood Type'**
  String get bloodType;

  /// Insurance field label
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get insurance;

  /// List view tooltip
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get listView;

  /// Grid view tooltip
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get gridView;

  /// No patient found message
  ///
  /// In en, this message translates to:
  /// **'No Patient Found'**
  String get noPatientFound;

  /// No patients available message
  ///
  /// In en, this message translates to:
  /// **'No Patients Available'**
  String get noPatientsAvailable;

  /// Try another search message
  ///
  /// In en, this message translates to:
  /// **'Try another search or modify the filters'**
  String get tryAnotherSearch;

  /// Start by adding patients message
  ///
  /// In en, this message translates to:
  /// **'Start by adding patients'**
  String get startByAddingPatients;

  /// Search medical records placeholder
  ///
  /// In en, this message translates to:
  /// **'Search by patient, diagnosis, symptoms...'**
  String get searchByPatient;

  /// Search filters section title
  ///
  /// In en, this message translates to:
  /// **'Search Filters'**
  String get searchFilters;

  /// Search patient field label
  ///
  /// In en, this message translates to:
  /// **'Search Patient'**
  String get searchPatient;

  /// Search patient placeholder
  ///
  /// In en, this message translates to:
  /// **'Name, email or phone...'**
  String get nameEmailOrPhone;

  /// CNI number field label
  ///
  /// In en, this message translates to:
  /// **'CNI Number'**
  String get cniNumber;

  /// Date label
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// Reset button
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No medical records found message
  ///
  /// In en, this message translates to:
  /// **'No medical records found'**
  String get noMedicalRecordsFound;

  /// Try modifying search message
  ///
  /// In en, this message translates to:
  /// **'Try modifying your search criteria'**
  String get tryModifyingSearch;

  /// Record number label
  ///
  /// In en, this message translates to:
  /// **'Record #{number}'**
  String recordNumber(int number);

  /// Doctor label
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get doctor;

  /// Specialty field label
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get specialty;

  /// Unknown patient label
  ///
  /// In en, this message translates to:
  /// **'Unknown Patient'**
  String get unknownPatient;

  /// Unknown doctor label
  ///
  /// In en, this message translates to:
  /// **'Unknown Doctor'**
  String get unknownDoctor;

  /// Insurance not available label
  ///
  /// In en, this message translates to:
  /// **'Insurance N/A'**
  String get insuranceNA;

  /// Unknown blood group label
  ///
  /// In en, this message translates to:
  /// **'Unknown Group'**
  String get unknownGroup;

  /// Filter info message
  ///
  /// In en, this message translates to:
  /// **'Shows only patients with appointments in the selected period.'**
  String get showsOnlyPatientsWithAppointments;

  /// Monthly prescriptions chart title
  ///
  /// In en, this message translates to:
  /// **'Monthly Prescriptions'**
  String get monthlyPrescriptions;

  /// OR divider text
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// Continue with Google button text
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// Powered by text
  ///
  /// In en, this message translates to:
  /// **'Powered by'**
  String get poweredBy;

  /// ProDoc app name
  ///
  /// In en, this message translates to:
  /// **'ProDoc'**
  String get proDoc;

  /// Book appointment screen title
  ///
  /// In en, this message translates to:
  /// **'Book Appointment'**
  String get bookAppointment;

  /// Online booking title
  ///
  /// In en, this message translates to:
  /// **'Online Booking'**
  String get onlineBooking;

  /// Header for online booking screen
  ///
  /// In en, this message translates to:
  /// **'Online Booking'**
  String get onlineBookingHeader;

  /// Subheader for online booking screen
  ///
  /// In en, this message translates to:
  /// **'Schedule your consultation in just a few clicks'**
  String get onlineBookingSubheader;

  /// Option to book appointment for oneself
  ///
  /// In en, this message translates to:
  /// **'Book for me'**
  String get bookForMe;

  /// Option to book appointment for someone else
  ///
  /// In en, this message translates to:
  /// **'Someone else'**
  String get someoneElse;

  /// Title for appointment confirmation screen
  ///
  /// In en, this message translates to:
  /// **'Appointment Confirmed!'**
  String get appointmentConfirmedTitle;

  /// Detailed message on appointment confirmation screen
  ///
  /// In en, this message translates to:
  /// **'Your appointment request has been sent successfully! We will confirm your appointment as soon as possible.'**
  String get appointmentRequestSentDetails;

  /// Success message for appointment request
  ///
  /// In en, this message translates to:
  /// **'Your appointment request has been sent successfully!'**
  String get appointmentRequestSentSuccess;

  /// Service selection label
  ///
  /// In en, this message translates to:
  /// **'Desired Service'**
  String get desiredService;

  /// Doctor selection label
  ///
  /// In en, this message translates to:
  /// **'Doctor / Responsible'**
  String get doctorOrResponsible;

  /// Date selection label
  ///
  /// In en, this message translates to:
  /// **'Appointment Date'**
  String get appointmentDate;

  /// Additional notes label
  ///
  /// In en, this message translates to:
  /// **'Additional Notes (Optional)'**
  String get additionalNotesOptional;

  /// Confirm appointment button label
  ///
  /// In en, this message translates to:
  /// **'Confirm Appointment'**
  String get confirmAppointment;

  /// Full name input label
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullNameLabel;

  /// Email address input label
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddressLabel;

  /// Phone number input label
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumberLabel;

  /// Label for optional email address field
  ///
  /// In en, this message translates to:
  /// **'Email Address (Optional)'**
  String get emailAddressOptional;

  /// Personal information section title
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// Validation message for service selection
  ///
  /// In en, this message translates to:
  /// **'Please select a service'**
  String get pleaseSelectService;

  /// Validation message for doctor selection
  ///
  /// In en, this message translates to:
  /// **'Please select a doctor'**
  String get pleaseSelectDoctor;

  /// Validation message for date selection
  ///
  /// In en, this message translates to:
  /// **'Please select a date'**
  String get pleaseSelectDate;

  /// Validation message for time slot selection
  ///
  /// In en, this message translates to:
  /// **'Please select a time slot'**
  String get pleaseSelectTimeSlot;

  /// Name required validation message
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// Validation message for email field
  ///
  /// In en, this message translates to:
  /// **'Email address is required'**
  String get emailRequired;

  /// Validation message for invalid email
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get invalidEmail;

  /// Validation message for phone number field
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get phoneRequired;

  /// Loading message for time slots
  ///
  /// In en, this message translates to:
  /// **'Loading time slots...'**
  String get loadingTimeSlots;

  /// Hint text for notes field
  ///
  /// In en, this message translates to:
  /// **'Describe your symptoms or reasons for consultation...'**
  String get describeSymptoms;

  /// No time slots available message
  ///
  /// In en, this message translates to:
  /// **'No time slots available for this date'**
  String get noTimeSlotsAvailable;

  /// Instruction for user to select a different date
  ///
  /// In en, this message translates to:
  /// **'Please select another date'**
  String get pleaseSelectAnotherDate;

  /// Placeholder for date field
  ///
  /// In en, this message translates to:
  /// **'Select a date'**
  String get selectDate;

  /// Add item button
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get addItem;

  /// Add item manually button
  ///
  /// In en, this message translates to:
  /// **'Add Item Manually'**
  String get addItemManually;

  /// Retry button
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Confirm button
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmation;

  /// Public visibility option
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get public;

  /// Private visibility option
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get private;

  /// Public visibility description
  ///
  /// In en, this message translates to:
  /// **'Public (visible to authorized staff)'**
  String get publicDescription;

  /// Private visibility description
  ///
  /// In en, this message translates to:
  /// **'Private (only you)'**
  String get privateDescription;

  /// Choose visibility dialog title
  ///
  /// In en, this message translates to:
  /// **'Choose visibility'**
  String get chooseVisibility;

  /// Visibility label
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get visibility;

  /// Button to change visibility to public
  ///
  /// In en, this message translates to:
  /// **'Change to Public'**
  String get changeToPublic;

  /// Button to change visibility to private
  ///
  /// In en, this message translates to:
  /// **'Change to Private'**
  String get changeToPrivate;

  /// Description for public visibility
  ///
  /// In en, this message translates to:
  /// **'Visible to all authorized users'**
  String get visibleToAllAuthorized;

  /// Description for private visibility
  ///
  /// In en, this message translates to:
  /// **'Only visible to assigned doctor and admin'**
  String get onlyVisibleToDoctorAndAdmin;

  /// Success message when visibility is updated
  ///
  /// In en, this message translates to:
  /// **'Visibility updated to {visibility}'**
  String visibilityUpdated(String visibility);

  /// Create new medical record option
  ///
  /// In en, this message translates to:
  /// **'Create New Medical Record'**
  String get createNewMedicalRecord;

  /// Start with empty form subtitle
  ///
  /// In en, this message translates to:
  /// **'Start with empty form'**
  String get startWithEmptyForm;

  /// Delete attachment button
  ///
  /// In en, this message translates to:
  /// **'Delete Attachment'**
  String get deleteAttachment;

  /// Attachment deleted success message
  ///
  /// In en, this message translates to:
  /// **'Attachment deleted'**
  String get attachmentDeleted;

  /// PDF URL not available error
  ///
  /// In en, this message translates to:
  /// **'PDF URL not available'**
  String get pdfUrlNotAvailable;

  /// PDF downloaded success message
  ///
  /// In en, this message translates to:
  /// **'PDF downloaded'**
  String get pdfDownloaded;

  /// Unable to open PDF error
  ///
  /// In en, this message translates to:
  /// **'Unable to open PDF'**
  String get unableToOpenPdf;

  /// Error opening PDF message
  ///
  /// In en, this message translates to:
  /// **'Error opening PDF'**
  String get errorOpeningPdf;

  /// Unable to open file error
  ///
  /// In en, this message translates to:
  /// **'Unable to open file'**
  String get unableToOpenFile;

  /// Error opening message
  ///
  /// In en, this message translates to:
  /// **'Error opening'**
  String get errorOpening;

  /// Unable to read file error
  ///
  /// In en, this message translates to:
  /// **'Unable to read file. Please try again.'**
  String get unableToReadFile;

  /// File path not available error
  ///
  /// In en, this message translates to:
  /// **'File path not available. Please try again.'**
  String get filePathNotAvailable;

  /// File does not exist error
  ///
  /// In en, this message translates to:
  /// **'File does not exist'**
  String get fileDoesNotExist;

  /// Error selecting file message
  ///
  /// In en, this message translates to:
  /// **'Error selecting file'**
  String get errorSelectingFile;

  /// Confirm delete dialog title
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get confirmDelete;

  /// Confirm deletion dialog title
  ///
  /// In en, this message translates to:
  /// **'Confirm Deletion'**
  String get confirmDeletion;

  /// Unable to edit appointment error
  ///
  /// In en, this message translates to:
  /// **'Unable to edit this appointment'**
  String get unableToEditAppointment;

  /// Unable to call error
  ///
  /// In en, this message translates to:
  /// **'Unable to call'**
  String get unableToCall;

  /// Unable to open WhatsApp error
  ///
  /// In en, this message translates to:
  /// **'Unable to open WhatsApp'**
  String get unableToOpenWhatsApp;

  /// Unable to generate Google Calendar link error
  ///
  /// In en, this message translates to:
  /// **'Unable to generate Google Calendar link'**
  String get unableToGenerateGoogleCalendarLink;

  /// Error loading doctors message
  ///
  /// In en, this message translates to:
  /// **'Error loading doctors'**
  String get errorLoadingDoctors;

  /// Error searching patients message
  ///
  /// In en, this message translates to:
  /// **'Error searching patients'**
  String get errorSearchingPatients;

  /// Error searching message
  ///
  /// In en, this message translates to:
  /// **'Error searching'**
  String get errorSearching;

  /// Error loading appointments message
  ///
  /// In en, this message translates to:
  /// **'Error loading appointments'**
  String get errorLoadingAppointments;

  /// Error downloading message
  ///
  /// In en, this message translates to:
  /// **'Error downloading'**
  String get errorDownloading;

  /// Please select a patient message
  ///
  /// In en, this message translates to:
  /// **'Please select a patient'**
  String get pleaseSelectPatient;

  /// Invoice created successfully message
  ///
  /// In en, this message translates to:
  /// **'Invoice created successfully!'**
  String get invoiceCreatedSuccessfully;

  /// Pending status
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// Scheduled status
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get scheduled;

  /// Completed status
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// Cancelled status
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No Show status
  ///
  /// In en, this message translates to:
  /// **'No Show'**
  String get noShow;

  /// High priority
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// Medium priority
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// Low priority
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// Priority label
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// Period label
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get period;

  /// Start date label
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// End date label
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// Select button/label
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// Previous button
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// Next button
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Page label
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get page;

  /// Selected items count
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get selected;

  /// Clear button
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Mark as completed button
  ///
  /// In en, this message translates to:
  /// **'Mark as Completed'**
  String get markAsCompleted;

  /// Reschedule button
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get reschedule;

  /// View details button
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// Send WhatsApp reminder button
  ///
  /// In en, this message translates to:
  /// **'Send WhatsApp Reminder'**
  String get sendWhatsAppReminder;

  /// View prescriptions button
  ///
  /// In en, this message translates to:
  /// **'View Prescriptions'**
  String get viewPrescriptions;

  /// Access invoice button
  ///
  /// In en, this message translates to:
  /// **'Access Invoice'**
  String get accessInvoice;

  /// No appointments message
  ///
  /// In en, this message translates to:
  /// **'No Appointments'**
  String get noAppointments;

  /// Adjust filters message
  ///
  /// In en, this message translates to:
  /// **'Adjust your filters or create a new one.'**
  String get adjustYourFilters;

  /// Search requests placeholder
  ///
  /// In en, this message translates to:
  /// **'Search requests...'**
  String get searchRequests;

  /// No requests pending message
  ///
  /// In en, this message translates to:
  /// **'No appointment requests pending.'**
  String get noRequestsPending;

  /// No requests match message
  ///
  /// In en, this message translates to:
  /// **'No appointment requests match your search criteria.'**
  String get noRequestsMatch;

  /// Reject request title
  ///
  /// In en, this message translates to:
  /// **'Reject Request'**
  String get rejectRequest;

  /// Select reason label
  ///
  /// In en, this message translates to:
  /// **'Select a reason'**
  String get selectReason;

  /// Doctor unavailable reason
  ///
  /// In en, this message translates to:
  /// **'Doctor Unavailable'**
  String get doctorUnavailable;

  /// Time slot taken reason
  ///
  /// In en, this message translates to:
  /// **'Time Slot Taken'**
  String get timeSlotTaken;

  /// Incomplete information reason
  ///
  /// In en, this message translates to:
  /// **'Incomplete Information'**
  String get incompleteInformation;

  /// Service unavailable reason
  ///
  /// In en, this message translates to:
  /// **'Service Unavailable'**
  String get serviceUnavailable;

  /// Other reason option
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// Enter custom reason placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter a custom reason'**
  String get enterCustomReason;

  /// Submit rejection button
  ///
  /// In en, this message translates to:
  /// **'Submit Rejection'**
  String get submitRejection;

  /// Update and confirm button
  ///
  /// In en, this message translates to:
  /// **'Update and Confirm'**
  String get updateAndConfirm;

  /// Update appointment date and time title
  ///
  /// In en, this message translates to:
  /// **'Update appointment date and time'**
  String get updateAppointmentDateTime;

  /// Select date and time message
  ///
  /// In en, this message translates to:
  /// **'Please select a date and time.'**
  String get selectDateAndTime;

  /// Enter valid time message
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid time in HH:mm format (e.g. 19:59).'**
  String get enterValidTime;

  /// Attach files screen title
  ///
  /// In en, this message translates to:
  /// **'Attach Files'**
  String get attachFiles;

  /// Attach files to medical record subtitle
  ///
  /// In en, this message translates to:
  /// **'Attach Files to Medical Record'**
  String get attachFilesToMedicalRecord;

  /// Add attachment button tooltip
  ///
  /// In en, this message translates to:
  /// **'Add Attachment'**
  String get addAttachment;

  /// Choose option message
  ///
  /// In en, this message translates to:
  /// **'Choose an option to add a file'**
  String get chooseOption;

  /// Camera option
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// Take photo subtitle
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takePhoto;

  /// Gallery option
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// Choose image subtitle
  ///
  /// In en, this message translates to:
  /// **'Choose an image'**
  String get chooseImage;

  /// File option
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// Choose file subtitle
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get chooseFile;

  /// Selected files label
  ///
  /// In en, this message translates to:
  /// **'Selected Files'**
  String get selectedFiles;

  /// Upload files button
  ///
  /// In en, this message translates to:
  /// **'Upload Files'**
  String get uploadFiles;

  /// Uploading message
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploading;

  /// No files selected message
  ///
  /// In en, this message translates to:
  /// **'No files selected'**
  String get noFilesSelected;

  /// Add files button
  ///
  /// In en, this message translates to:
  /// **'Add Files'**
  String get addFiles;

  /// Back button
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Upload button
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// Select patient label
  ///
  /// In en, this message translates to:
  /// **'Select Patient'**
  String get selectPatient;

  /// Select record label
  ///
  /// In en, this message translates to:
  /// **'Select Record'**
  String get selectRecord;

  /// Record ID label
  ///
  /// In en, this message translates to:
  /// **'Record ID'**
  String get recordId;

  /// Files attached successfully title
  ///
  /// In en, this message translates to:
  /// **'Files attached successfully'**
  String get filesAttachedSuccessfully;

  /// Files uploaded successfully message
  ///
  /// In en, this message translates to:
  /// **'file(s) uploaded successfully'**
  String get filesUploadedSuccessfully;

  /// Files failed message
  ///
  /// In en, this message translates to:
  /// **'file(s) failed'**
  String get filesFailed;

  /// View record button
  ///
  /// In en, this message translates to:
  /// **'View Record'**
  String get viewRecord;

  /// View profile button
  ///
  /// In en, this message translates to:
  /// **'View Profile'**
  String get viewProfile;

  /// File upload failed message
  ///
  /// In en, this message translates to:
  /// **'File upload failed'**
  String get fileUploadFailed;

  /// No patients found message
  ///
  /// In en, this message translates to:
  /// **'No patients found'**
  String get noPatientsFound;

  /// Cannot read file error
  ///
  /// In en, this message translates to:
  /// **'Cannot read file. Please try again.'**
  String get cannotReadFile;

  /// Error selecting files message
  ///
  /// In en, this message translates to:
  /// **'Error selecting files'**
  String get errorSelectingFiles;

  /// Search for patient placeholder
  ///
  /// In en, this message translates to:
  /// **'Search for a patient...'**
  String get searchForPatient;

  /// Select medical record label
  ///
  /// In en, this message translates to:
  /// **'Select Medical Record'**
  String get selectMedicalRecord;

  /// Please select record and files message
  ///
  /// In en, this message translates to:
  /// **'Please select a record and files'**
  String get pleaseSelectRecordAndFiles;

  /// Close button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Appointment updated successfully message
  ///
  /// In en, this message translates to:
  /// **'Appointment updated successfully'**
  String get appointmentUpdatedSuccessfully;

  /// Status changed to message
  ///
  /// In en, this message translates to:
  /// **'Status changed to'**
  String get statusChangedTo;

  /// Do you want to change status message
  ///
  /// In en, this message translates to:
  /// **'Do you really want to change the status to'**
  String get doYouWantToChangeStatus;

  /// Do you want to change status of multiple message
  ///
  /// In en, this message translates to:
  /// **'Do you really want to change the status of'**
  String get doYouWantToChangeStatusOf;

  /// Appointments to message
  ///
  /// In en, this message translates to:
  /// **'appointments to'**
  String get appointmentsTo;

  /// Appointments updated message
  ///
  /// In en, this message translates to:
  /// **'appointments updated'**
  String get appointmentsUpdated;

  /// Appointments updated failed message
  ///
  /// In en, this message translates to:
  /// **'appointments updated, failed'**
  String get appointmentsUpdatedFailed;

  /// Status of appointments changed message
  ///
  /// In en, this message translates to:
  /// **'Status of appointments changed to'**
  String get statusOfAppointmentsChanged;

  /// Reminder sent to message
  ///
  /// In en, this message translates to:
  /// **'Reminder sent to'**
  String get reminderSentTo;

  /// For appointment message
  ///
  /// In en, this message translates to:
  /// **'for appointment'**
  String get forAppointment;

  /// Appointment details title
  ///
  /// In en, this message translates to:
  /// **'Appointment Details'**
  String get appointmentDetails;

  /// Appointment label
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get appointment;

  /// Phone label
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// Doctor email label
  ///
  /// In en, this message translates to:
  /// **'Doctor Email'**
  String get doctorEmail;

  /// Time label
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// Status label
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// Created at label
  ///
  /// In en, this message translates to:
  /// **'Created At'**
  String get createdAt;

  /// Updated at label
  ///
  /// In en, this message translates to:
  /// **'Updated At'**
  String get updatedAt;

  /// Notes label
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// Sending message
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sending;

  /// Sending WhatsApp reminder message
  ///
  /// In en, this message translates to:
  /// **'Sending WhatsApp reminder...'**
  String get sendingWhatsAppReminder;

  /// WhatsApp reminder sent successfully message
  ///
  /// In en, this message translates to:
  /// **'WhatsApp reminder sent successfully!'**
  String get whatsAppReminderSentSuccessfully;

  /// Failed to send WhatsApp reminder message
  ///
  /// In en, this message translates to:
  /// **'Failed to send WhatsApp reminder. Please try again.'**
  String get failedToSendWhatsAppReminder;

  /// Daily message limit reached message
  ///
  /// In en, this message translates to:
  /// **'Daily message limit reached. Please try again tomorrow.'**
  String get dailyMessageLimitReached;

  /// Edit appointment title
  ///
  /// In en, this message translates to:
  /// **'Edit Appointment'**
  String get editAppointment;

  /// Cannot edit appointment message
  ///
  /// In en, this message translates to:
  /// **'Cannot edit this appointment'**
  String get cannotEditAppointment;

  /// Please select time message
  ///
  /// In en, this message translates to:
  /// **'Please select a time'**
  String get pleaseSelectTime;

  /// No time slots available short message
  ///
  /// In en, this message translates to:
  /// **'No time slots available'**
  String get noTimeSlotsAvailableShort;

  /// Unknown label
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// Unknown service label
  ///
  /// In en, this message translates to:
  /// **'Unknown service'**
  String get unknownService;

  /// Unknown date label
  ///
  /// In en, this message translates to:
  /// **'Unknown date'**
  String get unknownDate;

  /// Invalid date message
  ///
  /// In en, this message translates to:
  /// **'Invalid date'**
  String get invalidDate;

  /// Quick statistics title
  ///
  /// In en, this message translates to:
  /// **'Quick Statistics'**
  String get quickStatistics;

  /// Advanced filters title
  ///
  /// In en, this message translates to:
  /// **'Advanced Filters'**
  String get advancedFilters;

  /// Show advanced filters tooltip
  ///
  /// In en, this message translates to:
  /// **'Show advanced filters'**
  String get showAdvancedFilters;

  /// Hide advanced filters tooltip
  ///
  /// In en, this message translates to:
  /// **'Hide advanced filters'**
  String get hideAdvancedFilters;

  /// Quick filters title
  ///
  /// In en, this message translates to:
  /// **'Quick Filters'**
  String get quickFilters;

  /// Search or quickly select message
  ///
  /// In en, this message translates to:
  /// **'Search or quickly select a status'**
  String get searchOrQuicklySelect;

  /// Export button
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// Export available soon message
  ///
  /// In en, this message translates to:
  /// **'Export available soon.'**
  String get exportAvailableSoon;

  /// List refreshed message
  ///
  /// In en, this message translates to:
  /// **'List refreshed'**
  String get listRefreshed;

  /// Statistics title
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// View statistics subtitle
  ///
  /// In en, this message translates to:
  /// **'View statistics'**
  String get viewStatistics;

  /// Refresh button
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Refresh list subtitle
  ///
  /// In en, this message translates to:
  /// **'Refresh list'**
  String get refreshList;

  /// End of results message
  ///
  /// In en, this message translates to:
  /// **'End of results.'**
  String get endOfResults;

  /// View prescriptions available soon message
  ///
  /// In en, this message translates to:
  /// **'View prescriptions available soon.'**
  String get viewPrescriptionsAvailableSoon;

  /// Invoice access available soon message
  ///
  /// In en, this message translates to:
  /// **'Invoice access available soon.'**
  String get invoiceAccessAvailableSoon;

  /// Billing coming soon message
  ///
  /// In en, this message translates to:
  /// **'Billing coming soon.'**
  String get billingComingSoon;

  /// Details tab label
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// Invoice button
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoice;

  /// WhatsApp button
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get whatsApp;

  /// Appointment number label
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get appointmentNumber;

  /// Patient label
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get patient;

  /// ID label
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get id;

  /// Actions label
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// Search patient doctor service placeholder
  ///
  /// In en, this message translates to:
  /// **'Search patient, doctor, service...'**
  String get searchPatientDoctorService;

  /// Success title
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get successTitle;

  /// Error title
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorTitle;

  /// Warning title
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warningTitle;

  /// Appointment confirmed message
  ///
  /// In en, this message translates to:
  /// **'Appointment confirmed! The patient can see it in their dashboard or calendar.'**
  String get appointmentConfirmed;

  /// Please select new date time message
  ///
  /// In en, this message translates to:
  /// **'Please select a new date or time for this appointment.'**
  String get pleaseSelectNewDateTime;

  /// Confirmation failed doctor not found
  ///
  /// In en, this message translates to:
  /// **'Confirmation failed: Doctor not found.'**
  String get confirmationFailed;

  /// Confirmation failed invalid time
  ///
  /// In en, this message translates to:
  /// **'Confirmation failed: The request time is invalid. Please correct the time.'**
  String get confirmationFailedInvalidTime;

  /// Confirmation failed error
  ///
  /// In en, this message translates to:
  /// **'Confirmation failed'**
  String get confirmationFailedError;

  /// Appointment updated confirmed message
  ///
  /// In en, this message translates to:
  /// **'Appointment updated and confirmed successfully!'**
  String get appointmentUpdatedConfirmed;

  /// New time outside availability message
  ///
  /// In en, this message translates to:
  /// **'The new selected time is still outside availability hours. Please choose another time.'**
  String get newTimeOutsideAvailability;

  /// Time conflict message
  ///
  /// In en, this message translates to:
  /// **'Time conflict with the new selected time. Please choose another slot.'**
  String get timeConflict;

  /// Update confirmation failed message
  ///
  /// In en, this message translates to:
  /// **'Update and confirmation failed'**
  String get updateConfirmationFailed;

  /// Request rejected successfully message
  ///
  /// In en, this message translates to:
  /// **'Appointment request rejected successfully'**
  String get requestRejectedSuccessfully;

  /// Rejection failed message
  ///
  /// In en, this message translates to:
  /// **'Rejection failed'**
  String get rejectionFailed;

  /// Please select rejection reason message
  ///
  /// In en, this message translates to:
  /// **'Please select a rejection reason'**
  String get pleaseSelectRejectionReason;

  /// Update appointment date time description
  ///
  /// In en, this message translates to:
  /// **'The selected time or date is not available or invalid. Please choose a new date and time in HH:mm format (e.g. 19:59).'**
  String get updateAppointmentDateTimeDesc;

  /// Doctor available from message
  ///
  /// In en, this message translates to:
  /// **'The doctor is available from'**
  String get doctorAvailableFrom;

  /// To label
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get to;

  /// Hour label
  ///
  /// In en, this message translates to:
  /// **'Hour'**
  String get hour;

  /// Hour format label
  ///
  /// In en, this message translates to:
  /// **'Time (HH:mm)'**
  String get hourFormat;

  /// Hour format hint
  ///
  /// In en, this message translates to:
  /// **'HH:mm (e.g. 19:59)'**
  String get hourFormatHint;

  /// Good morning greeting
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// Good afternoon greeting
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// Good evening greeting
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// Opening appointment message
  ///
  /// In en, this message translates to:
  /// **'Opening appointment'**
  String get openingAppointment;

  /// Opening prescription message
  ///
  /// In en, this message translates to:
  /// **'Opening prescription'**
  String get openingPrescription;

  /// Issued date label
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get issued;

  /// Download PDF tooltip
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get downloadPdf;

  /// All doctors filter
  ///
  /// In en, this message translates to:
  /// **'All Doctors'**
  String get allDoctors;

  /// Today's schedule title
  ///
  /// In en, this message translates to:
  /// **'Today\'s Schedule'**
  String get todaysSchedule;

  /// Active appointments subtitle
  ///
  /// In en, this message translates to:
  /// **'Active Appointments'**
  String get activeAppointments;

  /// Patients today title
  ///
  /// In en, this message translates to:
  /// **'Patients today'**
  String get patientsToday;

  /// Appointments list title
  ///
  /// In en, this message translates to:
  /// **'Appointments List'**
  String get appointmentsList;

  /// View all appointments subtitle
  ///
  /// In en, this message translates to:
  /// **'View all appointments'**
  String get viewAllAppointments;

  /// Doctor overview title
  ///
  /// In en, this message translates to:
  /// **'Doctor Overview'**
  String get doctorOverview;

  /// Upcoming appointments title
  ///
  /// In en, this message translates to:
  /// **'Upcoming Appointments'**
  String get upcomingAppointments;

  /// Recent appointments title
  ///
  /// In en, this message translates to:
  /// **'Recent Appointments'**
  String get recentAppointments;

  /// Recent prescriptions title
  ///
  /// In en, this message translates to:
  /// **'Recent Prescriptions'**
  String get recentPrescriptions;

  /// Receptionist overview title
  ///
  /// In en, this message translates to:
  /// **'Receptionist Overview'**
  String get receptionistOverview;

  /// Pending requests title
  ///
  /// In en, this message translates to:
  /// **'Pending Requests'**
  String get pendingRequests;

  /// Medical record details screen title
  ///
  /// In en, this message translates to:
  /// **'Medical Record Details'**
  String get medicalRecordDetails;

  /// Attachments tab label
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachments;

  /// General information section title
  ///
  /// In en, this message translates to:
  /// **'General Information'**
  String get generalInformation;

  /// Vital signs section title
  ///
  /// In en, this message translates to:
  /// **'Vital Signs'**
  String get vitalSigns;

  /// Blood pressure label
  ///
  /// In en, this message translates to:
  /// **'Blood Pressure'**
  String get bloodPressure;

  /// Weight label
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// Height label
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// Temperature label
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperature;

  /// Heart rate label
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get heartRate;

  /// Respiratory rate label
  ///
  /// In en, this message translates to:
  /// **'Respiratory Rate'**
  String get respiratoryRate;

  /// Allergies section title
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get allergies;

  /// Medical information section title
  ///
  /// In en, this message translates to:
  /// **'Medical Information'**
  String get medicalInformation;

  /// Symptoms label
  ///
  /// In en, this message translates to:
  /// **'Symptoms'**
  String get symptoms;

  /// Treatment label
  ///
  /// In en, this message translates to:
  /// **'Treatment'**
  String get treatment;

  /// Specialty data section title
  ///
  /// In en, this message translates to:
  /// **'Specialty Data'**
  String get specialtyData;

  /// No prescriptions message
  ///
  /// In en, this message translates to:
  /// **'No Prescriptions'**
  String get noPrescriptions;

  /// No prescriptions recorded message
  ///
  /// In en, this message translates to:
  /// **'No prescriptions have been recorded for this medical record'**
  String get noPrescriptionsRecorded;

  /// Prescription number label
  ///
  /// In en, this message translates to:
  /// **'Prescription #{number}'**
  String prescriptionNumber(int number);

  /// Created on label
  ///
  /// In en, this message translates to:
  /// **'Created on'**
  String get createdOn;

  /// No medical records found for patient message
  ///
  /// In en, this message translates to:
  /// **'No medical records found'**
  String get noMedicalRecordsFoundForPatient;

  /// Start by creating first medical record message
  ///
  /// In en, this message translates to:
  /// **'Start by creating the first medical record for this patient'**
  String get startByCreatingFirstMedicalRecord;

  /// No description provided for @newMedicalRecord.
  ///
  /// In en, this message translates to:
  /// **'New Medical Record'**
  String get newMedicalRecord;

  /// No description provided for @editMedicalRecord.
  ///
  /// In en, this message translates to:
  /// **'Edit Medical Record'**
  String get editMedicalRecord;

  /// No description provided for @patientAndDoctor.
  ///
  /// In en, this message translates to:
  /// **'Patient & Doctor'**
  String get patientAndDoctor;

  /// No description provided for @medicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Medical Details'**
  String get medicalDetails;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @selectPatientDoctorAndSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Select patient, doctor and specialty'**
  String get selectPatientDoctorAndSpecialty;

  /// No description provided for @createPatientHint.
  ///
  /// In en, this message translates to:
  /// **'Create a new patient to open a medical record.'**
  String get createPatientHint;

  /// No description provided for @createPatientButton.
  ///
  /// In en, this message translates to:
  /// **'Create Patient'**
  String get createPatientButton;

  /// No description provided for @selectASpecialty.
  ///
  /// In en, this message translates to:
  /// **'Select a specialty'**
  String get selectASpecialty;

  /// No description provided for @manageSpecialties.
  ///
  /// In en, this message translates to:
  /// **'Manage specialties'**
  String get manageSpecialties;

  /// No description provided for @editSpecialtyFields.
  ///
  /// In en, this message translates to:
  /// **'Edit fields for \"{name}\"'**
  String editSpecialtyFields(String name);

  /// No description provided for @errorLoadingSpecialties.
  ///
  /// In en, this message translates to:
  /// **'Error loading specialties'**
  String get errorLoadingSpecialties;

  /// No description provided for @loadingSpecialtyFields.
  ///
  /// In en, this message translates to:
  /// **'Loading specialty fields...'**
  String get loadingSpecialtyFields;

  /// No description provided for @cantFindSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find your specialty?'**
  String get cantFindSpecialty;

  /// No description provided for @createOne.
  ///
  /// In en, this message translates to:
  /// **'Create one'**
  String get createOne;

  /// No description provided for @goToSpecialtiesScreen.
  ///
  /// In en, this message translates to:
  /// **'Go to specialties screen'**
  String get goToSpecialtiesScreen;

  /// No description provided for @createSpecialtyTitle.
  ///
  /// In en, this message translates to:
  /// **'Create specialty'**
  String get createSpecialtyTitle;

  /// No description provided for @nameRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get nameRequiredLabel;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @specialtyDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Specialty description'**
  String get specialtyDescriptionHint;

  /// No description provided for @createButton.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createButton;

  /// No description provided for @nameIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameIsRequired;

  /// No description provided for @vitalSignsAndHistory.
  ///
  /// In en, this message translates to:
  /// **'Vital signs & history'**
  String get vitalSignsAndHistory;

  /// No description provided for @enterPatientVitalSigns.
  ///
  /// In en, this message translates to:
  /// **'Enter patient vital signs'**
  String get enterPatientVitalSigns;

  /// No description provided for @bloodPressureHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 120/80'**
  String get bloodPressureHint;

  /// No description provided for @weightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightKg;

  /// No description provided for @heightCm.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get heightCm;

  /// No description provided for @temperatureC.
  ///
  /// In en, this message translates to:
  /// **'Temperature (°C)'**
  String get temperatureC;

  /// No description provided for @heartRateBpm.
  ///
  /// In en, this message translates to:
  /// **'Heart rate (bpm)'**
  String get heartRateBpm;

  /// No description provided for @respiratoryRatePerMin.
  ///
  /// In en, this message translates to:
  /// **'Respiratory rate (/min)'**
  String get respiratoryRatePerMin;

  /// No description provided for @bmiLabel.
  ///
  /// In en, this message translates to:
  /// **'BMI'**
  String get bmiLabel;

  /// No description provided for @doesPatientHaveAllergies.
  ///
  /// In en, this message translates to:
  /// **'Does patient have allergies?'**
  String get doesPatientHaveAllergies;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @allergyDetails.
  ///
  /// In en, this message translates to:
  /// **'Allergy details'**
  String get allergyDetails;

  /// No description provided for @describeKnownAllergies.
  ///
  /// In en, this message translates to:
  /// **'Describe known allergies...'**
  String get describeKnownAllergies;

  /// No description provided for @specialtySpecificFields.
  ///
  /// In en, this message translates to:
  /// **'Specialty-specific fields'**
  String get specialtySpecificFields;

  /// No description provided for @addNewFieldFor.
  ///
  /// In en, this message translates to:
  /// **'Add new field for \"{name}\"'**
  String addNewFieldFor(String name);

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required field'**
  String get requiredField;

  /// No description provided for @thisFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get thisFieldRequired;

  /// No description provided for @pleaseEnterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get pleaseEnterValidNumber;

  /// No description provided for @describeSymptomsDiagnosisTreatment.
  ///
  /// In en, this message translates to:
  /// **'Describe symptoms, diagnosis and treatment'**
  String get describeSymptomsDiagnosisTreatment;

  /// No description provided for @symptomsHint.
  ///
  /// In en, this message translates to:
  /// **'Describe patient symptoms (optional)...'**
  String get symptomsHint;

  /// No description provided for @diagnosisHint.
  ///
  /// In en, this message translates to:
  /// **'Medical diagnosis (optional)...'**
  String get diagnosisHint;

  /// No description provided for @treatmentHint.
  ///
  /// In en, this message translates to:
  /// **'Prescribed treatment plan (optional)...'**
  String get treatmentHint;

  /// No description provided for @additionalNotes.
  ///
  /// In en, this message translates to:
  /// **'Additional notes'**
  String get additionalNotes;

  /// No description provided for @additionalNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Other observations or notes...'**
  String get additionalNotesHint;

  /// No description provided for @reviewAndSubmit.
  ///
  /// In en, this message translates to:
  /// **'Review & Submit'**
  String get reviewAndSubmit;

  /// No description provided for @notSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get notSelected;

  /// No description provided for @notEntered.
  ///
  /// In en, this message translates to:
  /// **'Not entered'**
  String get notEntered;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No description provided for @updateButton.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateButton;

  /// No description provided for @createRecordButton.
  ///
  /// In en, this message translates to:
  /// **'Create record'**
  String get createRecordButton;

  /// No description provided for @pleaseSelectPatientDoctorSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Please select patient, doctor and specialty'**
  String get pleaseSelectPatientDoctorSpecialty;

  /// No description provided for @medicalRecordUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Medical record updated successfully'**
  String get medicalRecordUpdatedSuccess;

  /// No description provided for @medicalRecordCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Medical record created successfully'**
  String get medicalRecordCreatedSuccess;

  /// No description provided for @noDoctorAvailable.
  ///
  /// In en, this message translates to:
  /// **'No doctor available. Please try again later.'**
  String get noDoctorAvailable;

  /// No description provided for @patientCreatedContinueRecord.
  ///
  /// In en, this message translates to:
  /// **'Patient created. You can continue with the medical record.'**
  String get patientCreatedContinueRecord;

  /// No description provided for @pleaseFillRequiredField.
  ///
  /// In en, this message translates to:
  /// **'Please fill the required field: {fieldLabel}'**
  String pleaseFillRequiredField(String fieldLabel);

  /// Title for subscription management screen
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get subscriptionsTitle;

  /// Subtitle showing tenant for subscription screen
  ///
  /// In en, this message translates to:
  /// **'Manage subscriptions for {tenant}'**
  String manageSubscriptionsFor(String tenant);

  /// Banner title when no active subscription
  ///
  /// In en, this message translates to:
  /// **'No active subscription'**
  String get noActiveSubscription;

  /// Banner description when no active subscription
  ///
  /// In en, this message translates to:
  /// **'Your subscription is expired or inactive. Some features may be limited.'**
  String get noActiveSubscriptionDesc;

  /// Button text to renew same plan
  ///
  /// In en, this message translates to:
  /// **'Renew same plan'**
  String get renewSamePlan;

  /// Button text to choose a new plan
  ///
  /// In en, this message translates to:
  /// **'Choose a plan'**
  String get choosePlan;

  /// Price and interval formatting
  ///
  /// In en, this message translates to:
  /// **'{price} / {interval}'**
  String pricePerInterval(String price, String interval);

  /// Label for start date
  ///
  /// In en, this message translates to:
  /// **'Start:'**
  String get startDate;

  /// Label for end date
  ///
  /// In en, this message translates to:
  /// **'End:'**
  String get endDate;

  /// Remaining days label
  ///
  /// In en, this message translates to:
  /// **'{count} day(s) left'**
  String daysLeft(int count);

  /// Cancel subscription button
  ///
  /// In en, this message translates to:
  /// **'Cancel subscription'**
  String get cancelSubscription;

  /// Upgrade plan button
  ///
  /// In en, this message translates to:
  /// **'Upgrade / change'**
  String get upgradePlan;

  /// No description provided for @referralProgram.
  ///
  /// In en, this message translates to:
  /// **'Referral Program'**
  String get referralProgram;

  /// No description provided for @referralShort.
  ///
  /// In en, this message translates to:
  /// **'Win'**
  String get referralShort;

  /// No description provided for @referralCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Referral code copied!'**
  String get referralCodeCopied;

  /// No description provided for @referralShareMessage.
  ///
  /// In en, this message translates to:
  /// **'Use my referral code: %s'**
  String get referralShareMessage;

  /// No description provided for @referralShareAndEarn.
  ///
  /// In en, this message translates to:
  /// **'Share & Earn'**
  String get referralShareAndEarn;

  /// No description provided for @referralYouEarnDays.
  ///
  /// In en, this message translates to:
  /// **'You earn %s days'**
  String get referralYouEarnDays;

  /// No description provided for @referralFriendGetsDays.
  ///
  /// In en, this message translates to:
  /// **'Your friend gets %s days'**
  String get referralFriendGetsDays;

  /// No description provided for @referralYourCode.
  ///
  /// In en, this message translates to:
  /// **'Your referral code'**
  String get referralYourCode;

  /// No description provided for @referralCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get referralCopyLink;

  /// No description provided for @referralShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get referralShare;

  /// No description provided for @referralReferrals.
  ///
  /// In en, this message translates to:
  /// **'Referrals'**
  String get referralReferrals;

  /// No description provided for @referralPendingDays.
  ///
  /// In en, this message translates to:
  /// **'Pending days'**
  String get referralPendingDays;

  /// No description provided for @referralApplyCode.
  ///
  /// In en, this message translates to:
  /// **'Apply referral code'**
  String get referralApplyCode;

  /// No description provided for @referralHaveCode.
  ///
  /// In en, this message translates to:
  /// **'Have a referral code? Enter it to get free subscription days.'**
  String get referralHaveCode;

  /// No description provided for @referralEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter 8-character code'**
  String get referralEnterCode;

  /// No description provided for @referralValidCode.
  ///
  /// In en, this message translates to:
  /// **'Valid code from'**
  String get referralValidCode;

  /// No description provided for @referralApplying.
  ///
  /// In en, this message translates to:
  /// **'Applying...'**
  String get referralApplying;

  /// No description provided for @referralHistory.
  ///
  /// In en, this message translates to:
  /// **'Referral history'**
  String get referralHistory;

  /// No description provided for @referralYouUsedCode.
  ///
  /// In en, this message translates to:
  /// **'You used a referral code'**
  String get referralYouUsedCode;

  /// No description provided for @referralReferredBy.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get referralReferredBy;

  /// No description provided for @referralReward.
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get referralReward;

  /// No description provided for @referralDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get referralDays;

  /// No description provided for @referralPeopleYouReferred.
  ///
  /// In en, this message translates to:
  /// **'People you referred'**
  String get referralPeopleYouReferred;

  /// No description provided for @referralNoReferralsYet.
  ///
  /// In en, this message translates to:
  /// **'No referrals yet. Share your code!'**
  String get referralNoReferralsYet;

  /// No description provided for @referralDialogInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite friends & colleagues — everyone wins!'**
  String get referralDialogInvite;

  /// No description provided for @referralDialogYouEarn.
  ///
  /// In en, this message translates to:
  /// **'Share your code. You win free days. They win free days. Simple!'**
  String get referralDialogYouEarn;

  /// No description provided for @referralDialogShareLink.
  ///
  /// In en, this message translates to:
  /// **'Share your personal link from the Referral Program page.'**
  String get referralDialogShareLink;

  /// No description provided for @referralDialogOpen.
  ///
  /// In en, this message translates to:
  /// **'Open Referral Program'**
  String get referralDialogOpen;

  /// No description provided for @referralDialogYourCode.
  ///
  /// In en, this message translates to:
  /// **'Your referral code'**
  String get referralDialogYourCode;

  /// No description provided for @referralDialogYouWinDays.
  ///
  /// In en, this message translates to:
  /// **'You win %s days free!'**
  String get referralDialogYouWinDays;

  /// No description provided for @referralDialogTheyGetDays.
  ///
  /// In en, this message translates to:
  /// **'They win %s days free!'**
  String get referralDialogTheyGetDays;

  /// No description provided for @referralPromoTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite & earn free days'**
  String get referralPromoTitle;

  /// No description provided for @referralPromoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share your referral link with colleagues'**
  String get referralPromoSubtitle;

  /// Status label for pending subscription
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingStatus;

  /// Status label for suspended subscription
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get suspendedStatus;

  /// Status label for expired subscription
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expiredStatus;

  /// Status label for active subscription
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeStatus;

  /// OK button text
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Years label
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get years;

  /// New patient button
  ///
  /// In en, this message translates to:
  /// **'New Patient'**
  String get newPatient;

  /// Full name field label
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// Male gender option
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// Female gender option
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// Address field label
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// Insurance type field label
  ///
  /// In en, this message translates to:
  /// **'Insurance Type'**
  String get insuranceType;

  /// Insurance number field label
  ///
  /// In en, this message translates to:
  /// **'Insurance Number'**
  String get insuranceNumber;

  /// Service field label
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get service;

  /// Available time slots section header
  ///
  /// In en, this message translates to:
  /// **'Available Time Slots'**
  String get availableTimeSlots;

  /// High priority option
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get highPriority;

  /// Medium priority option
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get mediumPriority;

  /// Low priority option
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get lowPriority;

  /// Billing options section header
  ///
  /// In en, this message translates to:
  /// **'Billing Options'**
  String get billingOptions;

  /// Generate invoice checkbox
  ///
  /// In en, this message translates to:
  /// **'Generate Invoice'**
  String get generateInvoice;

  /// Add amount checkbox
  ///
  /// In en, this message translates to:
  /// **'Add Amount'**
  String get addAmount;

  /// Amount field label
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// Mark as paid checkbox
  ///
  /// In en, this message translates to:
  /// **'Mark as Paid'**
  String get markAsPaid;

  /// Notifications section header
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// WhatsApp notification checkbox
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get whatsapp;

  /// Optional field label
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// Create button text
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Enter patient name title
  ///
  /// In en, this message translates to:
  /// **'Enter Patient Name'**
  String get enterPatientName;

  /// Enter patient name description
  ///
  /// In en, this message translates to:
  /// **'Enter patient name, email or CNI number'**
  String get enterPatientNameDescription;

  /// Enter patient name hint text
  ///
  /// In en, this message translates to:
  /// **'Enter patient name, email or CNI'**
  String get enterPatientNameHint;

  /// Patient name field label
  ///
  /// In en, this message translates to:
  /// **'Patient Name'**
  String get patientName;

  /// At least 2 characters required validation message
  ///
  /// In en, this message translates to:
  /// **'At least 2 characters required'**
  String get atLeast2CharactersRequired;

  /// Find patient button text
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get findPatient;

  /// Appointment created success message
  ///
  /// In en, this message translates to:
  /// **'Appointment Created!'**
  String get appointmentCreated;

  /// Clinic Info menu item
  ///
  /// In en, this message translates to:
  /// **'Clinic Info'**
  String get clinicInfo;

  /// About us menu item
  ///
  /// In en, this message translates to:
  /// **'About us'**
  String get aboutUs;

  /// Call button
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// Follow us section
  ///
  /// In en, this message translates to:
  /// **'Follow Us'**
  String get followUs;

  /// Our services section
  ///
  /// In en, this message translates to:
  /// **'Our Services'**
  String get ourServices;

  /// Working hours section
  ///
  /// In en, this message translates to:
  /// **'Working Hours'**
  String get workingHours;

  /// Closed status
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// Monday
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// Tuesday
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// Wednesday
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// Thursday
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// Friday
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// Saturday
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// Sunday
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// Button to navigate to clinic info screen
  ///
  /// In en, this message translates to:
  /// **'See Clinic Info'**
  String get seeClinicInfo;

  /// Label for map button
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @healthOverview.
  ///
  /// In en, this message translates to:
  /// **'Health Overview'**
  String get healthOverview;

  /// No description provided for @upcomingVisitsStat.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Visits'**
  String get upcomingVisitsStat;

  /// No description provided for @scheduledAppointmentsStat.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Appointments'**
  String get scheduledAppointmentsStat;

  /// No description provided for @unpaidInvoicesStat.
  ///
  /// In en, this message translates to:
  /// **'Unpaid Invoices'**
  String get unpaidInvoicesStat;

  /// No description provided for @activePrescriptionsStat.
  ///
  /// In en, this message translates to:
  /// **'Active Prescriptions'**
  String get activePrescriptionsStat;

  /// No description provided for @inProgressStat.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get inProgressStat;

  /// No description provided for @myCalendarStat.
  ///
  /// In en, this message translates to:
  /// **'My Calendar'**
  String get myCalendarStat;

  /// No description provided for @agendaStat.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get agendaStat;

  /// No description provided for @manageMyDatesStat.
  ///
  /// In en, this message translates to:
  /// **'Manage my dates'**
  String get manageMyDatesStat;

  /// No description provided for @yourPrescriptionsSection.
  ///
  /// In en, this message translates to:
  /// **'Your Prescriptions'**
  String get yourPrescriptionsSection;

  /// No description provided for @medication.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get medication;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get days;

  /// No description provided for @timesPerDay.
  ///
  /// In en, this message translates to:
  /// **'x/day'**
  String get timesPerDay;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'more'**
  String get more;

  /// No description provided for @noMedicationsRecorded.
  ///
  /// In en, this message translates to:
  /// **'No medications recorded'**
  String get noMedicationsRecorded;

  /// No description provided for @prescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get prescriptionLabel;

  /// Upcoming tab label
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// Past tab label
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get past;

  /// Patient information section title
  ///
  /// In en, this message translates to:
  /// **'Patient Information'**
  String get patientInformation;

  /// Follow-up date label
  ///
  /// In en, this message translates to:
  /// **'Follow-up Date'**
  String get followUpDate;

  /// No medications message
  ///
  /// In en, this message translates to:
  /// **'No medications'**
  String get noMedications;

  /// Button text to clear patient selection and search again
  ///
  /// In en, this message translates to:
  /// **'Not this patient? Search again or add manually'**
  String get notThisPatient;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
