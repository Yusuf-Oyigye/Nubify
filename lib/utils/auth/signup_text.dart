//===================================================
// SIGNUP TEXT IN EVERY LANGUAGE
//
// The signup steps show in the language picked on the
// first step. The English text is the key; anything not
// translated here stays in English (e.g. server errors).
//
// Arabic and French are complete. Hausa, Yoruba and Hindi
// are good first versions: a native speaker should read
// them once and fix any wording here.
//===================================================

abstract final class SignupText {
  /// Arabic reads right to left.
  static bool isRtl(String code) => code == 'ar';

  /// [english] in the language [code], with {name}
  /// placeholders filled from [values].
  static String tr(
    String code,
    String english, [
    Map<String, Object> values = const <String, Object>{},
  ]) {
    String text = _translations[code]?[english] ?? english;
    values.forEach((String key, Object value) {
      text = text.replaceAll('{$key}', '$value');
    });
    return text;
  }

  static const Map<String, Map<String, String>>
  _translations = <String, Map<String, String>>{
    //=============================================
    // ARABIC
    //=============================================
    'ar': <String, String>{
      'Join Nubify': 'انضم إلى Nubify',
      'Step {n} of {total}': 'الخطوة {n} من {total}',
      'Choose your language': 'اختر لغتك',
      'Nubify will show the next steps in this language.':
          'سيعرض Nubify الخطوات التالية بهذه اللغة.',
      'How can we reach you?': 'كيف يمكننا التواصل معك؟',
      'Use an email you can open. Your number is optional.':
          'استخدم بريدًا إلكترونيًا يمكنك فتحه. رقمك اختياري.',
      'Tell us about you': 'أخبرنا عنك',
      'Your name, your unique @username and who you are.':
          'اسمك، واسم المستخدم الخاص بك، ومن أنت.',
      'Your campus life': 'حياتك الجامعية',
      'Pick your faculty and share a little about you.':
          'اختر كليتك وشاركنا القليل عنك.',
      'Secure your account': 'أمّن حسابك',
      'Use at least 6 characters.': 'استخدم 6 أحرف على الأقل.',
      'Your profile picture': 'صورتك الشخصية',
      'Add a clear photo of yourself.': 'أضف صورة واضحة لك.',
      'Email': 'البريد الإلكتروني',
      'Mobile number': 'رقم الهاتف',
      '{label} (optional)': '{label} (اختياري)',
      "Starts with 010, 011, 012, 015 or +20, and stays private. If you don't have an Egyptian number, you can skip this.":
          'يبدأ بـ 010 أو 011 أو 012 أو 015 أو \u200E+20\u200E، ويبقى خاصًا. إذا لم يكن لديك رقم مصري، يمكنك تخطي هذا.',
      'Full name': 'الاسم الكامل',
      'Emojis are welcome in your name ✨': 'يمكنك إضافة الإيموجي إلى اسمك ✨',
      'I am': 'أنا',
      'Male': 'ذكر',
      'Female': 'أنثى',
      'Hobbies': 'الهوايات',
      'Favourite quote': 'اقتباسك المفضل',
      'Password': 'كلمة المرور',
      'Gallery': 'المعرض',
      'Camera': 'الكاميرا',
      'Remove photo': 'إزالة الصورة',
      'Back': 'رجوع',
      'Next': 'التالي',
      'Create account': 'إنشاء حساب',
      'Already have an account?': 'لديك حساب بالفعل؟',
      'Log in': 'تسجيل الدخول',
      'Please choose your faculty': 'يرجى اختيار كليتك',
      'Please type your faculty': 'يرجى كتابة اسم كليتك',
      'Please enter your password': 'يرجى إدخال كلمة المرور',
      'Password must be at least 6 characters':
          'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل',
      'Enter a valid Egyptian number beginning 010, 011, 012, or 015, or leave it empty':
          'أدخل رقمًا مصريًا صحيحًا يبدأ بـ 010 أو 011 أو 012 أو 015، أو اتركه فارغًا',
      'Please enter your full name': 'يرجى إدخال اسمك الكامل',
      'Please choose male or female': 'يرجى اختيار ذكر أو أنثى',
      'Username': 'اسم المستخدم',
      'Checking…': 'جارٍ التحقق…',
      'Username must contain at least 3 characters.':
          'يجب أن يحتوي اسم المستخدم على 3 أحرف على الأقل.',
      'Username cannot exceed 20 characters.':
          'لا يمكن أن يتجاوز اسم المستخدم 20 حرفًا.',
      'Username must start with an English letter.':
          'يجب أن يبدأ اسم المستخدم بحرف إنجليزي.',
      'Only English letters, numbers, underscores and periods are allowed.':
          'يُسمح فقط بالأحرف الإنجليزية والأرقام والشرطة السفلية (_) والنقطة (.).',
      'Consecutive periods are not allowed.': 'لا يُسمح بنقطتين متتاليتين.',
      'Consecutive underscores are not allowed.':
          'لا يُسمح بشرطتين سفليتين متتاليتين.',
      'Username cannot end with a period.':
          'لا يمكن أن ينتهي اسم المستخدم بنقطة.',
      'This username is already taken.': 'اسم المستخدم هذا مستخدم بالفعل.',
      'Username is available.': 'اسم المستخدم متاح.',
      'Could not check right now. We will check again when you continue.':
          'تعذر التحقق الآن. سنتحقق مرة أخرى عند المتابعة.',
      'Faculty': 'الكلية',
      'Choose your faculty': 'اختر كليتك',
      'Type your faculty': 'اكتب كليتك',
      'Enter your faculty name': 'أدخل اسم كليتك',
      'Please enter your email.': 'يرجى إدخال بريدك الإلكتروني.',
      'Your email must contain "@".': 'يجب أن يحتوي بريدك الإلكتروني على "@".',
      'This email address does not look right. Please check it.':
          'يبدو أن عنوان البريد الإلكتروني غير صحيح. يرجى التحقق منه.',
    },

    //=============================================
    // FRENCH
    //=============================================
    'fr': <String, String>{
      'Join Nubify': 'Rejoindre Nubify',
      'Step {n} of {total}': 'Étape {n} sur {total}',
      'Choose your language': 'Choisissez votre langue',
      'Nubify will show the next steps in this language.':
          'Nubify affichera les étapes suivantes dans cette langue.',
      'How can we reach you?': 'Comment pouvons-nous vous joindre ?',
      'Use an email you can open. Your number is optional.':
          'Utilisez un e-mail que vous pouvez ouvrir. Votre numéro est facultatif.',
      'Tell us about you': 'Parlez-nous de vous',
      'Your name, your unique @username and who you are.':
          'Votre nom, votre @nom d’utilisateur unique et qui vous êtes.',
      'Your campus life': 'Votre vie sur le campus',
      'Pick your faculty and share a little about you.':
          'Choisissez votre faculté et parlez un peu de vous.',
      'Secure your account': 'Sécurisez votre compte',
      'Use at least 6 characters.': 'Utilisez au moins 6 caractères.',
      'Your profile picture': 'Votre photo de profil',
      'Add a clear photo of yourself.': 'Ajoutez une photo nette de vous.',
      'Email': 'E-mail',
      'Mobile number': 'Numéro de mobile',
      '{label} (optional)': '{label} (facultatif)',
      "Starts with 010, 011, 012, 015 or +20, and stays private. If you don't have an Egyptian number, you can skip this.":
          'Commence par 010, 011, 012, 015 ou +20 et reste privé. Si vous n’avez pas de numéro égyptien, vous pouvez passer.',
      'Full name': 'Nom complet',
      'Emojis are welcome in your name ✨':
          'Les emojis sont les bienvenus dans votre nom ✨',
      'I am': 'Je suis',
      'Male': 'Homme',
      'Female': 'Femme',
      'Hobbies': 'Loisirs',
      'Favourite quote': 'Citation préférée',
      'Password': 'Mot de passe',
      'Gallery': 'Galerie',
      'Camera': 'Appareil photo',
      'Remove photo': 'Retirer la photo',
      'Back': 'Retour',
      'Next': 'Suivant',
      'Create account': 'Créer un compte',
      'Already have an account?': 'Vous avez déjà un compte ?',
      'Log in': 'Se connecter',
      'Please choose your faculty': 'Veuillez choisir votre faculté',
      'Please type your faculty': 'Veuillez saisir votre faculté',
      'Please enter your password': 'Veuillez saisir votre mot de passe',
      'Password must be at least 6 characters':
          'Le mot de passe doit contenir au moins 6 caractères',
      'Enter a valid Egyptian number beginning 010, 011, 012, or 015, or leave it empty':
          'Saisissez un numéro égyptien valide commençant par 010, 011, 012 ou 015, ou laissez vide',
      'Please enter your full name': 'Veuillez saisir votre nom complet',
      'Please choose male or female': 'Veuillez choisir homme ou femme',
      'Username': 'Nom d’utilisateur',
      'Checking…': 'Vérification…',
      'Username must contain at least 3 characters.':
          'Le nom d’utilisateur doit contenir au moins 3 caractères.',
      'Username cannot exceed 20 characters.':
          'Le nom d’utilisateur ne peut pas dépasser 20 caractères.',
      'Username must start with an English letter.':
          'Le nom d’utilisateur doit commencer par une lettre de l’alphabet anglais.',
      'Only English letters, numbers, underscores and periods are allowed.':
          'Seuls les lettres anglaises, les chiffres, les tirets bas et les points sont autorisés.',
      'Consecutive periods are not allowed.':
          'Deux points à la suite ne sont pas autorisés.',
      'Consecutive underscores are not allowed.':
          'Deux tirets bas à la suite ne sont pas autorisés.',
      'Username cannot end with a period.':
          'Le nom d’utilisateur ne peut pas se terminer par un point.',
      'This username is already taken.': 'Ce nom d’utilisateur est déjà pris.',
      'Username is available.': 'Ce nom d’utilisateur est disponible.',
      'Could not check right now. We will check again when you continue.':
          'Vérification impossible pour le moment. Nous vérifierons à nouveau quand vous continuerez.',
      'Faculty': 'Faculté',
      'Choose your faculty': 'Choisissez votre faculté',
      'Type your faculty': 'Saisissez votre faculté',
      'Enter your faculty name': 'Entrez le nom de votre faculté',
      'Please enter your email.': 'Veuillez saisir votre e-mail.',
      'Your email must contain "@".': 'Votre e-mail doit contenir « @ ».',
      'This email address does not look right. Please check it.':
          'Cette adresse e-mail ne semble pas correcte. Veuillez la vérifier.',
    },

    //=============================================
    // HAUSA
    //=============================================
    'ha': <String, String>{
      'Join Nubify': 'Shiga Nubify',
      'Step {n} of {total}': 'Mataki na {n} cikin {total}',
      'Choose your language': 'Zaɓi harshenka',
      'Nubify will show the next steps in this language.':
          'Nubify za ta nuna matakai na gaba da wannan harshe.',
      'How can we reach you?': 'Ta yaya za mu same ka?',
      'Use an email you can open. Your number is optional.':
          'Yi amfani da imel ɗin da kake iya buɗewa. Lambar wayarka ba dole ba ce.',
      'Tell us about you': 'Faɗa mana game da kai',
      'Your name, your unique @username and who you are.':
          'Sunanka, @sunan mai amfani naka na musamman, da kuma kai wane ne.',
      'Your campus life': 'Rayuwarka a jami’a',
      'Pick your faculty and share a little about you.':
          'Zaɓi tsangayarka kuma ka ɗan faɗa mana game da kai.',
      'Secure your account': 'Tsare asusunka',
      'Use at least 6 characters.': 'Yi amfani da aƙalla haruffa 6.',
      'Your profile picture': 'Hoton furofayil ɗinka',
      'Add a clear photo of yourself.': 'Saka hotonka bayyananne.',
      'Email': 'Imel',
      'Mobile number': 'Lambar waya',
      '{label} (optional)': '{label} (ba dole ba)',
      "Starts with 010, 011, 012, 015 or +20, and stays private. If you don't have an Egyptian number, you can skip this.":
          'Tana farawa da 010, 011, 012, 015 ko +20, kuma za ta kasance a sirri. Idan ba ka da lambar Masar, za ka iya tsallake wannan.',
      'Full name': 'Cikakken suna',
      'Emojis are welcome in your name ✨':
          'Ana maraba da emoji a cikin sunanka ✨',
      'I am': 'Ni',
      'Male': 'Namiji',
      'Female': 'Mace',
      'Hobbies': 'Abubuwan sha’awa',
      'Favourite quote': 'Maganar da ka fi so',
      'Password': 'Kalmar sirri',
      'Gallery': 'Hotuna',
      'Camera': 'Kyamara',
      'Remove photo': 'Cire hoto',
      'Back': 'Koma baya',
      'Next': 'Gaba',
      'Create account': 'Ƙirƙiri asusu',
      'Already have an account?': 'Kana da asusu tuni?',
      'Log in': 'Shiga',
      'Please choose your faculty': 'Da fatan za ka zaɓi tsangayarka',
      'Please type your faculty': 'Da fatan za ka rubuta tsangayarka',
      'Please enter your password': 'Da fatan za ka shigar da kalmar sirrinka',
      'Password must be at least 6 characters':
          'Kalmar sirri dole ta kai aƙalla haruffa 6',
      'Enter a valid Egyptian number beginning 010, 011, 012, or 015, or leave it empty':
          'Shigar da ingantacciyar lambar Masar mai farawa da 010, 011, 012 ko 015, ko ka bar ta babu komai',
      'Please enter your full name':
          'Da fatan za ka shigar da cikakken sunanka',
      'Please choose male or female': 'Da fatan za ka zaɓi namiji ko mace',
      'Username': 'Sunan mai amfani',
      'Checking…': 'Ana dubawa…',
      'Username must contain at least 3 characters.':
          'Sunan mai amfani dole ya kai aƙalla haruffa 3.',
      'Username cannot exceed 20 characters.':
          'Sunan mai amfani ba zai wuce haruffa 20 ba.',
      'Username must start with an English letter.':
          'Sunan mai amfani dole ya fara da harafin Turanci.',
      'Only English letters, numbers, underscores and periods are allowed.':
          'Haruffan Turanci, lambobi, layin ƙasa (_) da ɗigo (.) kaɗai ake yarda da su.',
      'Consecutive periods are not allowed.':
          'Ba a yarda da ɗigo biyu a jere ba.',
      'Consecutive underscores are not allowed.':
          'Ba a yarda da layin ƙasa biyu a jere ba.',
      'Username cannot end with a period.':
          'Sunan mai amfani ba zai ƙare da ɗigo ba.',
      'This username is already taken.':
          'An riga an ɗauki wannan sunan mai amfani.',
      'Username is available.': 'Sunan mai amfani yana nan.',
      'Could not check right now. We will check again when you continue.':
          'Ba a iya dubawa yanzu ba. Za mu sake dubawa idan ka ci gaba.',
      'Faculty': 'Tsangaya',
      'Choose your faculty': 'Zaɓi tsangayarka',
      'Type your faculty': 'Rubuta tsangayarka',
      'Enter your faculty name': 'Shigar da sunan tsangayarka',
      'Please enter your email.': 'Da fatan za ka shigar da imel ɗinka.',
      'Your email must contain "@".': 'Imel ɗinka dole ya ƙunshi "@".',
      'This email address does not look right. Please check it.':
          'Wannan adireshin imel bai yi daidai ba. Da fatan za ka duba shi.',
    },

    //=============================================
    // YORUBA
    //=============================================
    'yo': <String, String>{
      'Join Nubify': 'Darapọ̀ mọ́ Nubify',
      'Step {n} of {total}': 'Ìgbésẹ̀ {n} nínú {total}',
      'Choose your language': 'Yan èdè rẹ',
      'Nubify will show the next steps in this language.':
          'Nubify yóò fi àwọn ìgbésẹ̀ tó kàn hàn ní èdè yìí.',
      'How can we reach you?': 'Báwo ni a ṣe lè kàn sí ọ?',
      'Use an email you can open. Your number is optional.':
          'Lo ímeèlì tí o lè ṣí. Nọ́mbà rẹ kò pọndandan.',
      'Tell us about you': 'Sọ fún wa nípa ara rẹ',
      'Your name, your unique @username and who you are.':
          'Orúkọ rẹ, @orúkọ olùmúlò rẹ àti ẹni tí o jẹ́.',
      'Your campus life': 'Ìgbésí ayé rẹ ní ilé ẹ̀kọ́',
      'Pick your faculty and share a little about you.':
          'Yan ẹ̀ka ẹ̀kọ́ rẹ kí o sì sọ díẹ̀ nípa ara rẹ.',
      'Secure your account': 'Dáàbò bo àkọọ́lẹ̀ rẹ',
      'Use at least 6 characters.': 'Lo ó kéré tán lẹ́tà mẹ́fà.',
      'Your profile picture': 'Àwòrán profaili rẹ',
      'Add a clear photo of yourself.': 'Fi àwòrán rẹ tó ṣe kedere kún un.',
      'Email': 'Ímeèlì',
      'Mobile number': 'Nọ́mbà fóònù',
      '{label} (optional)': '{label} (kò pọndandan)',
      "Starts with 010, 011, 012, 015 or +20, and stays private. If you don't have an Egyptian number, you can skip this.":
          'Ó bẹ̀rẹ̀ pẹ̀lú 010, 011, 012, 015 tàbí +20, ó sì máa wà ní ìkọ̀kọ̀. Tí o kò bá ní nọ́mbà Íjíbítì, o lè fò ó.',
      'Full name': 'Orúkọ kíkún',
      'Emojis are welcome in your name ✨': 'A gba emoji láàyè nínú orúkọ rẹ ✨',
      'I am': 'Mo jẹ́',
      'Male': 'Ọkùnrin',
      'Female': 'Obìnrin',
      'Hobbies': 'Àwọn ohun tí o fẹ́ràn',
      'Favourite quote': 'Ọ̀rọ̀ tí o fẹ́ràn jù',
      'Password': 'Ọ̀rọ̀ aṣínà',
      'Gallery': 'Àwòrán',
      'Camera': 'Kámẹ́rà',
      'Remove photo': 'Yọ àwòrán kúrò',
      'Back': 'Padà',
      'Next': 'Tó kàn',
      'Create account': 'Ṣẹ̀dá àkọọ́lẹ̀',
      'Already have an account?': 'Ṣé o ti ní àkọọ́lẹ̀?',
      'Log in': 'Wọlé',
      'Please choose your faculty': 'Jọ̀wọ́ yan ẹ̀ka ẹ̀kọ́ rẹ',
      'Please type your faculty': 'Jọ̀wọ́ kọ ẹ̀ka ẹ̀kọ́ rẹ',
      'Please enter your password': 'Jọ̀wọ́ tẹ ọ̀rọ̀ aṣínà rẹ',
      'Password must be at least 6 characters':
          'Ọ̀rọ̀ aṣínà gbọ́dọ̀ ní ó kéré tán lẹ́tà mẹ́fà',
      'Enter a valid Egyptian number beginning 010, 011, 012, or 015, or leave it empty':
          'Tẹ nọ́mbà Íjíbítì tó tọ́ tí ó bẹ̀rẹ̀ pẹ̀lú 010, 011, 012 tàbí 015, tàbí fi sílẹ̀ ní òfo',
      'Please enter your full name': 'Jọ̀wọ́ tẹ orúkọ kíkún rẹ',
      'Please choose male or female': 'Jọ̀wọ́ yan ọkùnrin tàbí obìnrin',
      'Username': 'Orúkọ olùmúlò',
      'Checking…': 'À ń ṣàyẹ̀wò…',
      'Username must contain at least 3 characters.':
          'Orúkọ olùmúlò gbọ́dọ̀ ní ó kéré tán lẹ́tà mẹ́ta.',
      'Username cannot exceed 20 characters.':
          'Orúkọ olùmúlò kò lè ju lẹ́tà ogún lọ.',
      'Username must start with an English letter.':
          'Orúkọ olùmúlò gbọ́dọ̀ bẹ̀rẹ̀ pẹ̀lú lẹ́tà Gẹ̀ẹ́sì.',
      'Only English letters, numbers, underscores and periods are allowed.':
          'Lẹ́tà Gẹ̀ẹ́sì, nọ́mbà, ìlà ìsàlẹ̀ (_) àti àmì àdúró (.) nìkan ni a gbà.',
      'Consecutive periods are not allowed.':
          'A kò gba àmì àdúró méjì tẹ̀léra.',
      'Consecutive underscores are not allowed.':
          'A kò gba ìlà ìsàlẹ̀ méjì tẹ̀léra.',
      'Username cannot end with a period.':
          'Orúkọ olùmúlò kò lè parí pẹ̀lú àmì àdúró.',
      'This username is already taken.': 'Ẹlòmíràn ti mú orúkọ olùmúlò yìí.',
      'Username is available.': 'Orúkọ olùmúlò yìí wà.',
      'Could not check right now. We will check again when you continue.':
          'A kò lè ṣàyẹ̀wò báyìí. A ó tún ṣàyẹ̀wò nígbà tí o bá tẹ̀síwájú.',
      'Faculty': 'Ẹ̀ka ẹ̀kọ́',
      'Choose your faculty': 'Yan ẹ̀ka ẹ̀kọ́ rẹ',
      'Type your faculty': 'Kọ ẹ̀ka ẹ̀kọ́ rẹ',
      'Enter your faculty name': 'Tẹ orúkọ ẹ̀ka ẹ̀kọ́ rẹ',
      'Please enter your email.': 'Jọ̀wọ́ tẹ ímeèlì rẹ.',
      'Your email must contain "@".': 'Ímeèlì rẹ gbọ́dọ̀ ní "@".',
      'This email address does not look right. Please check it.':
          'Àdírẹ́sì ímeèlì yìí kò dàbí pé ó tọ́. Jọ̀wọ́ ṣàyẹ̀wò rẹ̀.',
    },

    //=============================================
    // HINDI
    //=============================================
    'hi': <String, String>{
      'Join Nubify': 'Nubify से जुड़ें',
      'Step {n} of {total}': 'चरण {n} / {total}',
      'Choose your language': 'अपनी भाषा चुनें',
      'Nubify will show the next steps in this language.':
          'Nubify अगले चरण इसी भाषा में दिखाएगा।',
      'How can we reach you?': 'हम आपसे कैसे संपर्क करें?',
      'Use an email you can open. Your number is optional.':
          'ऐसा ईमेल इस्तेमाल करें जिसे आप खोल सकें। आपका नंबर वैकल्पिक है।',
      'Tell us about you': 'अपने बारे में बताएं',
      'Your name, your unique @username and who you are.':
          'आपका नाम, आपका अनोखा @यूज़रनेम और आप कौन हैं।',
      'Your campus life': 'आपका कैंपस जीवन',
      'Pick your faculty and share a little about you.':
          'अपनी फैकल्टी चुनें और अपने बारे में थोड़ा बताएं।',
      'Secure your account': 'अपना खाता सुरक्षित करें',
      'Use at least 6 characters.': 'कम से कम 6 अक्षर इस्तेमाल करें।',
      'Your profile picture': 'आपकी प्रोफ़ाइल फ़ोटो',
      'Add a clear photo of yourself.': 'अपनी एक साफ़ फ़ोटो जोड़ें।',
      'Email': 'ईमेल',
      'Mobile number': 'मोबाइल नंबर',
      '{label} (optional)': '{label} (वैकल्पिक)',
      "Starts with 010, 011, 012, 015 or +20, and stays private. If you don't have an Egyptian number, you can skip this.":
          '010, 011, 012, 015 या +20 से शुरू होता है और निजी रहता है। अगर आपके पास मिस्र का नंबर नहीं है, तो आप इसे छोड़ सकते हैं।',
      'Full name': 'पूरा नाम',
      'Emojis are welcome in your name ✨': 'आपके नाम में इमोजी का स्वागत है ✨',
      'I am': 'मैं हूँ',
      'Male': 'पुरुष',
      'Female': 'महिला',
      'Hobbies': 'शौक',
      'Favourite quote': 'पसंदीदा उद्धरण',
      'Password': 'पासवर्ड',
      'Gallery': 'गैलरी',
      'Camera': 'कैमरा',
      'Remove photo': 'फ़ोटो हटाएँ',
      'Back': 'वापस',
      'Next': 'आगे',
      'Create account': 'खाता बनाएँ',
      'Already have an account?': 'पहले से खाता है?',
      'Log in': 'लॉग इन करें',
      'Please choose your faculty': 'कृपया अपनी फैकल्टी चुनें',
      'Please type your faculty': 'कृपया अपनी फैकल्टी लिखें',
      'Please enter your password': 'कृपया अपना पासवर्ड डालें',
      'Password must be at least 6 characters':
          'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए',
      'Enter a valid Egyptian number beginning 010, 011, 012, or 015, or leave it empty':
          '010, 011, 012 या 015 से शुरू होने वाला सही मिस्र का नंबर डालें, या इसे खाली छोड़ दें',
      'Please enter your full name': 'कृपया अपना पूरा नाम डालें',
      'Please choose male or female': 'कृपया पुरुष या महिला चुनें',
      'Username': 'यूज़रनेम',
      'Checking…': 'जाँच हो रही है…',
      'Username must contain at least 3 characters.':
          'यूज़रनेम में कम से कम 3 अक्षर होने चाहिए।',
      'Username cannot exceed 20 characters.':
          'यूज़रनेम 20 अक्षरों से ज़्यादा नहीं हो सकता।',
      'Username must start with an English letter.':
          'यूज़रनेम अंग्रेज़ी अक्षर से शुरू होना चाहिए।',
      'Only English letters, numbers, underscores and periods are allowed.':
          'केवल अंग्रेज़ी अक्षर, अंक, अंडरस्कोर (_) और पीरियड (.) की अनुमति है।',
      'Consecutive periods are not allowed.':
          'लगातार दो पीरियड की अनुमति नहीं है।',
      'Consecutive underscores are not allowed.':
          'लगातार दो अंडरस्कोर की अनुमति नहीं है।',
      'Username cannot end with a period.':
          'यूज़रनेम पीरियड पर खत्म नहीं हो सकता।',
      'This username is already taken.': 'यह यूज़रनेम पहले से लिया जा चुका है।',
      'Username is available.': 'यूज़रनेम उपलब्ध है।',
      'Could not check right now. We will check again when you continue.':
          'अभी जाँच नहीं हो सकी। आगे बढ़ने पर हम फिर से जाँचेंगे।',
      'Faculty': 'फैकल्टी',
      'Choose your faculty': 'अपनी फैकल्टी चुनें',
      'Type your faculty': 'अपनी फैकल्टी लिखें',
      'Enter your faculty name': 'अपनी फैकल्टी का नाम डालें',
      'Please enter your email.': 'कृपया अपना ईमेल डालें।',
      'Your email must contain "@".': 'आपके ईमेल में "@" होना चाहिए।',
      'This email address does not look right. Please check it.':
          'यह ईमेल पता सही नहीं लग रहा। कृपया इसे जाँच लें।',
    },
  };
}
