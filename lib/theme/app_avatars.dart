import 'package:flutter/material.dart';

/// รายชื่อไอคอนอวาตาร์ที่เลือกได้ตอน Onboarding / Edit Profile
/// เก็บแค่ "index" ใน UserModel.avatarIndex ไม่ผูก UI (IconData) เข้ากับ DB
/// โดยตรง — ถ้าจะเพิ่ม/สลับลำดับไอคอนในอนาคต แก้ที่ไฟล์นี้จุดเดียว
const List<IconData> heroAvatarIcons = [
  Icons.person_rounded,
  Icons.shield_rounded,
  Icons.sports_kabaddi_rounded,
  Icons.auto_awesome_rounded,
  Icons.fitness_center_rounded,
];

/// คืน IconData ตาม index อย่างปลอดภัย — กัน index เพี้ยน (เช่นข้อมูลเก่า
/// ก่อนมีฟีเจอร์นี้ที่ avatar_index เป็น 0 เสมอ หรือ index นอกช่วงในอนาคต
/// ถ้าลดจำนวนไอคอนในลิสต์)
IconData heroAvatarIcon(int index) {
  if (index < 0 || index >= heroAvatarIcons.length) {
    return heroAvatarIcons.first;
  }
  return heroAvatarIcons[index];
}
