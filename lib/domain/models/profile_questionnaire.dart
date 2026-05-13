/// Respostas do questionário pós-código (persistido em RTDB).
class ProfileQuestionnaire {
  final String name;
  final int age;
  final String gender;
  final String education;

  const ProfileQuestionnaire({
    required this.name,
    required this.age,
    required this.gender,
    required this.education,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'age': age,
        'gender': gender,
        'education': education,
      };
}
