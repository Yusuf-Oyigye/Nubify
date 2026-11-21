import 'package:flutter/material.dart';

//===================================================
// NUB — FACULTY FIELDS (USED BY THE FILTER CHIPS)
//===================================================

enum NubFacultyField {
  health('Health Sciences', Icons.favorite_border_rounded),
  technology('Engineering & Tech', Icons.memory_rounded),
  business('Business & Media', Icons.campaign_outlined),
  arts('Arts', Icons.palette_outlined);

  const NubFacultyField(this.label, this.icon);

  final String label;
  final IconData icon;
}

//===================================================
// NUB — FACULTY MODEL
//===================================================

class NubFaculty {
  const NubFaculty({
    required this.id,
    required this.name,
    required this.shortName,
    required this.arabicName,
    required this.tagline,
    required this.image,
    required this.icon,
    required this.color,
    required this.field,
    required this.about,
    required this.subjects,
    required this.pathways,
  });

  final String id;
  final String name;
  final String shortName;
  final String arabicName;
  final String tagline;
  final String image;
  final IconData icon;
  final Color color;
  final NubFacultyField field;
  final String about;
  final List<String> subjects;
  final List<String> pathways;

  // A darker shade of the faculty colour, used for premium gradients.
  Color get deepColor => Color.lerp(color, const Color(0xFF0B1426), .55)!;

  // "01", "02" ... based on the faculty's position in the list.
  String get number =>
      (nubFaculties.indexOf(this) + 1).toString().padLeft(2, '0');
}

//===================================================
// NUB — ALL TEN FACULTIES
//===================================================

const nubFaculties = <NubFaculty>[
  //=================================================
  // 1. MEDICINE
  //=================================================
  NubFaculty(
    id: 'medicine',
    name: 'Faculty of Medicine',
    shortName: 'Medicine',
    arabicName: 'كلية الطب البشري',
    tagline:
    'Preparing highly qualified doctors to provide quality healthcare.',
    image: 'assets/images/faculties/medicine.webp',
    icon: Icons.medical_services_outlined,
    color: Color(0xFFD9434E),
    field: NubFacultyField.health,
    about:
    'The Faculty of Medicine aims to prepare highly qualified doctors with the scientific knowledge, clinical skills, professional ethics, and practical experience required to provide quality healthcare. Students receive comprehensive education in basic medical sciences, including anatomy, physiology, biochemistry, histology, microbiology, immunology, pathology, pharmacology, and parasitology. As students progress, they study clinical disciplines such as internal medicine, surgery, pediatrics, obstetrics and gynecology, ophthalmology, ENT, orthopedics, and other medical specialties. The faculty emphasizes clinical reasoning, disease diagnosis, treatment planning, patient communication, medical research, and evidence-based medicine. Its goal is to graduate competent physicians capable of contributing to healthcare services, medical research, and community health.',
    subjects: [
      'Anatomy',
      'Physiology',
      'Biochemistry',
      'Histology',
      'Microbiology',
      'Immunology',
      'Pathology',
      'Pharmacology',
      'Parasitology',
      'Internal Medicine',
      'Surgery',
      'Pediatrics',
      'Obstetrics & Gynecology',
      'Ophthalmology',
      'ENT',
      'Orthopedics',
    ],
    pathways: ['Healthcare services', 'Medical research', 'Community health'],
  ),

  //=================================================
  // 2. ORAL AND DENTAL MEDICINE
  //=================================================
  NubFaculty(
    id: 'dental',
    name: 'Faculty of Oral and Dental Medicine',
    shortName: 'Oral & Dental Medicine',
    arabicName: 'كلية طب الفم والأسنان',
    tagline:
    'Diagnosing, preventing and treating diseases of the mouth and teeth.',
    image: 'assets/images/faculties/dental.webp',
    icon: Icons.sentiment_satisfied_alt_rounded,
    color: Color(0xFF1E9FD0),
    field: NubFacultyField.health,
    about:
    'The Faculty of Oral and Dental Medicine prepares students to become competent dental professionals capable of diagnosing, preventing, and treating diseases affecting the teeth, gums, mouth, and surrounding structures. The academic programme combines foundational medical sciences with specialized dental education, including dental anatomy, oral biology, dental materials, oral pathology, periodontology, endodontics, prosthodontics, orthodontics, oral surgery, and pediatric dentistry. Students develop practical skills through laboratory exercises, simulation training, and supervised clinical practice. The faculty emphasizes preventive dentistry, patient management, oral health education, clinical decision-making, and modern dental technologies. Its mission is to graduate qualified dentists who can provide comprehensive oral healthcare and contribute to dental research and public health.',
    subjects: [
      'Dental Anatomy',
      'Oral Biology',
      'Dental Materials',
      'Oral Pathology',
      'Periodontology',
      'Endodontics',
      'Prosthodontics',
      'Orthodontics',
      'Oral Surgery',
      'Pediatric Dentistry',
    ],
    pathways: ['Comprehensive oral healthcare', 'Dental research', 'Public health'],
  ),

  //=================================================
  // 3. PHARMACY
  //=================================================
  NubFaculty(
    id: 'pharmacy',
    name: 'Faculty of Pharmacy',
    shortName: 'Pharmacy',
    arabicName: 'كلية الصيدلة',
    tagline: 'From drug discovery to the safe use of medicines.',
    image: 'assets/images/faculties/pharmacy.webp',
    icon: Icons.medication_outlined,
    color: Color(0xFF1FA971),
    field: NubFacultyField.health,
    about:
    'The Faculty of Pharmacy focuses on pharmaceutical sciences, medication development, drug safety, and the appropriate use of medicines in healthcare. Students study a broad range of subjects, including pharmaceutical chemistry, pharmacology, pharmacognosy, pharmaceutics, microbiology, biochemistry, clinical pharmacy, and medicinal chemistry. The programme provides knowledge about how drugs are discovered, formulated, manufactured, distributed, and used to prevent and treat diseases. Students also develop skills in medication counselling, pharmaceutical care, drug interactions, dosage calculations, and patient safety. Through laboratory training and practical learning, graduates are prepared for professional opportunities in community pharmacies, hospitals, pharmaceutical industries, drug manufacturing, research laboratories, regulatory organizations, and clinical pharmacy services.',
    subjects: [
      'Pharmaceutical Chemistry',
      'Pharmacology',
      'Pharmacognosy',
      'Pharmaceutics',
      'Microbiology',
      'Biochemistry',
      'Clinical Pharmacy',
      'Medicinal Chemistry',
    ],
    pathways: [
      'Community pharmacies',
      'Hospitals',
      'Pharmaceutical industries',
      'Drug manufacturing',
      'Research laboratories',
      'Regulatory organizations',
      'Clinical pharmacy services',
    ],
  ),

  //=================================================
  // 4. PHYSICAL THERAPY
  //=================================================
  NubFaculty(
    id: 'physical_therapy',
    name: 'Faculty of Physical Therapy',
    shortName: 'Physical Therapy',
    arabicName: 'كلية العلاج الطبيعي',
    tagline: 'Helping people recover movement, strength and independence.',
    image: 'assets/images/faculties/physical_therapy.webp',
    icon: Icons.accessibility_new_rounded,
    color: Color(0xFFE7812F),
    field: NubFacultyField.health,
    about:
    "The Faculty of Physical Therapy prepares students to help individuals recover, maintain, and improve their physical movement, mobility, strength, and overall functional abilities. The programme covers medical and rehabilitation sciences, including anatomy, physiology, kinesiology, biomechanics, therapeutic exercises, electrotherapy, manual therapy, and rehabilitation techniques. Students learn how to assess patients, identify movement limitations, develop rehabilitation programmes, and monitor recovery. Specialized areas include musculoskeletal rehabilitation, neurological rehabilitation, pediatric physical therapy, cardiopulmonary rehabilitation, and sports injuries. Practical training helps students develop the clinical skills needed to work with patients recovering from injuries, surgeries, neurological disorders, and physical disabilities. The faculty aims to produce skilled rehabilitation professionals who improve patients' independence and quality of life.",
    subjects: [
      'Anatomy',
      'Physiology',
      'Kinesiology',
      'Biomechanics',
      'Therapeutic Exercises',
      'Electrotherapy',
      'Manual Therapy',
      'Rehabilitation Techniques',
    ],
    pathways: [
      'Musculoskeletal rehabilitation',
      'Neurological rehabilitation',
      'Pediatric physical therapy',
      'Cardiopulmonary rehabilitation',
      'Sports injuries',
    ],
  ),

  //=================================================
  // 5. NURSING
  //=================================================
  NubFaculty(
    id: 'nursing',
    name: 'Faculty of Nursing',
    shortName: 'Nursing',
    arabicName: 'كلية التمريض',
    tagline: 'Professional nurses delivering safe and effective care.',
    image: 'assets/images/faculties/nursing.webp',
    icon: Icons.monitor_heart_outlined,
    color: Color(0xFFE05591),
    field: NubFacultyField.health,
    about:
    'The Faculty of Nursing aims to prepare professional nurses with the knowledge, practical abilities, communication skills, and ethical values necessary to deliver safe and effective healthcare. Students study fundamental nursing concepts alongside medical sciences such as anatomy, physiology, microbiology, pharmacology, nutrition, and pathology. Specialized nursing subjects include medical-surgical nursing, pediatric nursing, maternal and newborn nursing, psychiatric and mental health nursing, community health nursing, critical care nursing, and nursing management. The academic programme combines classroom instruction, laboratory simulations, and clinical placements in healthcare settings. Students learn patient assessment, medication administration, wound care, infection prevention, emergency response, health education, and collaboration with other healthcare professionals. Graduates can pursue careers in hospitals, clinics, community health centres, and other healthcare institutions.',
    subjects: [
      'Medical-Surgical Nursing',
      'Pediatric Nursing',
      'Maternal & Newborn Nursing',
      'Mental Health Nursing',
      'Community Health Nursing',
      'Critical Care Nursing',
      'Nursing Management',
      'Pharmacology',
      'Nutrition',
    ],
    pathways: [
      'Hospitals',
      'Clinics',
      'Community health centres',
      'Healthcare institutions',
    ],
  ),

  //=================================================
  // 6. ENGINEERING
  //=================================================
  NubFaculty(
    id: 'engineering',
    name: 'Faculty of Engineering',
    shortName: 'Engineering',
    arabicName: 'كلية الهندسة',
    tagline: 'Solving complex problems and building innovative technology.',
    image: 'assets/images/faculties/engineering.webp',
    icon: Icons.engineering_outlined,
    color: Color(0xFFD4A21C),
    field: NubFacultyField.technology,
    about:
    'The Faculty of Engineering provides students with the scientific, mathematical, technical, and practical foundations required to solve complex engineering problems and develop innovative technologies. The programme emphasizes engineering mathematics, physics, computer applications, technical design, materials science, and engineering principles. Depending on the available academic departments and specializations, students may study areas such as civil engineering, electrical engineering, mechanical engineering, communications, electronics, and other engineering disciplines. Practical education involves laboratory experiments, engineering projects, computer-aided design, technical analysis, and teamwork. Students develop problem-solving, critical-thinking, project-management, and design skills. The faculty prepares graduates for professional opportunities in construction, manufacturing, infrastructure, energy, telecommunications, industrial development, research, and technology-related industries.',
    subjects: [
      'Engineering Mathematics',
      'Physics',
      'Computer Applications',
      'Technical Design',
      'Materials Science',
      'Computer-Aided Design',
    ],
    pathways: [
      'Construction',
      'Manufacturing',
      'Infrastructure',
      'Energy',
      'Telecommunications',
      'Industrial development',
      'Research',
      'Technology industries',
    ],
  ),

  //=================================================
  // 7. COMPUTER SCIENCE
  //=================================================
  NubFaculty(
    id: 'computer_science',
    name: 'Faculty of Computer Science',
    shortName: 'Computer Science',
    arabicName: 'كلية علوم الحاسب',
    tagline: 'Software, systems and the digital innovations of tomorrow.',
    image: 'assets/images/faculties/computer_science.webp',
    icon: Icons.computer_rounded,
    color: Color(0xFF5468EE),
    field: NubFacultyField.technology,
    about:
    "The Faculty of Computer Science focuses on developing students' understanding of computing systems, software technologies, digital innovation, and modern information systems. Students learn programming, algorithms, data structures, computer architecture, operating systems, databases, software engineering, computer networks, and web development. The programme may also cover advanced technological fields such as artificial intelligence, machine learning, cybersecurity, data science, cloud computing, mobile application development, and computer graphics. Through practical assignments, programming projects, laboratory work, and collaborative activities, students develop the ability to design, develop, test, and maintain software and computer-based systems. The faculty prepares graduates for careers as software developers, programmers, data analysts, cybersecurity specialists, systems engineers, AI developers, and IT professionals.",
    subjects: [
      'Programming',
      'Algorithms',
      'Data Structures',
      'Computer Architecture',
      'Operating Systems',
      'Databases',
      'Software Engineering',
      'Computer Networks',
      'Web Development',
    ],
    pathways: [
      'Software developer',
      'Programmer',
      'Data analyst',
      'Cybersecurity specialist',
      'Systems engineer',
      'AI developer',
      'IT professional',
    ],
  ),

  //=================================================
  // 8. BUSINESS ADMINISTRATION
  //=================================================
  NubFaculty(
    id: 'business',
    name: 'Faculty of Business Administration',
    shortName: 'Business Administration',
    arabicName: 'كلية إدارة الأعمال',
    tagline: 'Leadership, finance and strategy for modern organisations.',
    image: 'assets/images/faculties/business.webp',
    icon: Icons.business_center_outlined,
    color: Color(0xFF139A8E),
    field: NubFacultyField.business,
    about:
    "The Faculty of Business Administration aims to develop students' knowledge and professional abilities in business, management, finance, accounting, marketing, and entrepreneurship. Students study the principles of organizational management, business economics, financial accounting, managerial accounting, human resource management, business communication, marketing strategies, and business law. The academic programme also develops skills in leadership, strategic planning, financial analysis, problem-solving, negotiation, and decision-making. Students learn how organizations operate, how businesses manage their resources, how financial decisions are made, and how companies compete in local and international markets. The faculty prepares graduates for professional careers in banking, accounting, marketing, business management, human resources, financial services, entrepreneurship, and corporate administration.",
    subjects: [
      'Organizational Management',
      'Business Economics',
      'Financial Accounting',
      'Managerial Accounting',
      'Human Resource Management',
      'Business Communication',
      'Marketing Strategies',
      'Business Law',
    ],
    pathways: [
      'Banking',
      'Accounting',
      'Marketing',
      'Business management',
      'Human resources',
      'Financial services',
      'Entrepreneurship',
      'Corporate administration',
    ],
  ),

  //=================================================
  // 9. MASS COMMUNICATION AND APPLIED LANGUAGES
  //=================================================
  NubFaculty(
    id: 'mass_communication',
    name: 'Faculty of Mass Communication and Applied Languages',
    shortName: 'Mass Comm & Languages',
    arabicName: 'كلية الإعلام واللغات التطبيقية',
    tagline: 'Journalism, media production and professional languages.',
    image: 'assets/images/faculties/mass_communication.webp',
    icon: Icons.mic_none_rounded,
    color: Color(0xFF8E5BE0),
    field: NubFacultyField.business,
    about:
    "The Faculty of Mass Communication and Applied Languages focuses on developing students' abilities in communication, journalism, media production, public relations, advertising, and language application. Students explore the principles of mass communication, media writing, digital journalism, broadcasting, television and radio production, public relations, advertising, and digital media. The applied languages component develops language proficiency and professional communication skills for academic, business, media, and international environments. Students gain practical experience in content creation, media presentation, research, translation, communication strategies, and digital storytelling. The faculty prepares graduates for careers in journalism, television, radio, digital media, public relations, advertising, corporate communication, translation, and other language-related professions.",
    subjects: [
      'Mass Communication',
      'Media Writing',
      'Digital Journalism',
      'Broadcasting',
      'TV & Radio Production',
      'Public Relations',
      'Advertising',
      'Digital Media',
      'Applied Languages',
    ],
    pathways: [
      'Journalism',
      'Television',
      'Radio',
      'Digital media',
      'Public relations',
      'Advertising',
      'Corporate communication',
      'Translation',
    ],
  ),

  //=================================================
  // 10. FINE ARTS
  //=================================================
  NubFaculty(
    id: 'fine_arts',
    name: 'Faculty of Fine Arts',
    shortName: 'Fine Arts',
    arabicName: 'كلية الفنون الجميلة',
    tagline: 'Creativity, visual expression and original artistic thinking.',
    image: 'assets/images/faculties/fine_arts.webp',
    icon: Icons.palette_outlined,
    color: Color(0xFFC74FCF),
    field: NubFacultyField.arts,
    about:
    'The Faculty of Fine Arts encourages creativity, artistic development, visual communication, and innovative thinking through specialized artistic education and practical experience. Students explore different forms of visual expression, including drawing, painting, sculpture, design, and other artistic disciplines, depending on the available departments and programmes. The academic experience combines artistic theory, creative experimentation, practical studio work, art history, visual composition, and the development of individual artistic techniques. Students learn how to communicate ideas through visual forms, develop original artistic concepts, and use traditional and modern creative tools. The faculty prepares graduates for careers in artistic production, creative industries, visual design, illustration, cultural institutions, exhibitions, and other professions involving artistic expression and design.',
    subjects: [
      'Drawing',
      'Painting',
      'Sculpture',
      'Design',
      'Art History',
      'Visual Composition',
      'Studio Practice',
    ],
    pathways: [
      'Artistic production',
      'Creative industries',
      'Visual design',
      'Illustration',
      'Cultural institutions',
      'Exhibitions',
    ],
  ),
];