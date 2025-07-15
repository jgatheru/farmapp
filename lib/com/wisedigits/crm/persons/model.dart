class Person {
  int? id;
  String? name;
  int? titleid;
  int? positionid;
  int? cadreid;
  int? specialityid;
  int? classeid;
  String? email;
  String? tel;
  int? regionid;
  int? subregionid;
  String? location;
  int? categoryid;
  final String? photoUrl;

  Person({
    this.id,
    this.name,
    this.titleid,
    this.positionid,
    this.cadreid,
    this.specialityid,
    this.classeid,
    this.email,
    this.tel,
    this.regionid,
    this.subregionid,
    this.location,
    this.categoryid,
    this.photoUrl
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'titleid': titleid,
      'positionid': positionid,
      'cadreid': cadreid,
      'specialityid': specialityid,
      'classeid': classeid,
      'email': email,
      'tel': tel,
      'regionid': regionid,
      'subregionid': subregionid,
      'location': location,
      'categoryid': categoryid,
      'photoUrl': photoUrl
    };
  }

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'],
      name: map['name'],
      titleid: map['titleid'],
      positionid: map['positionid'],
      cadreid: map['cadreid'],
      specialityid: map['specialityid'],
      classeid: map['classeid'],
      email: map['email'],
      tel: map['tel'],
      regionid: map['regionid'],
      subregionid: map['subregionid'],
      location: map['location'],
      categoryid: map['categoryid'],
      photoUrl: map['photoUrl']
    );
  }

  factory Person.fromJson(Map<String, dynamic> map) {
    return Person(
        id: map['id'],
        name: map['name'],
        titleid: map['titleid'],
        positionid: map['positionid'],
        cadreid: map['cadreid'],
        specialityid: map['specialityid'],
        classeid: map['classeid'],
        email: map['email'],
        tel: map['tel'],
        regionid: map['regionid'],
        subregionid: map['subregionid'],
        location: map['location'],
        categoryid: map['categoryid'],
        photoUrl: map['photoUrl']
    );
  }
}

List<Person> persons = [];