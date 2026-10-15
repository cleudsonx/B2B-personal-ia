import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/services/evolution_photo_service.dart';

void main() {
  group('EvolutionPhoto Model & Service Tests', () {
    test('serializes and deserializes EvolutionPhoto correctly', () {
      final now = DateTime.now();
      final photo = EvolutionPhoto(
        id: 'photo-123',
        studentId: 'student-abc',
        photoUrl: 'https://example.com/photo1.jpg',
        photoType: 'before',
        caption: 'Foto inicial',
        weightKg: 78.5,
        takenAt: now,
      );

      final json = photo.toJson();
      expect(json['id'], 'photo-123');
      expect(json['student_id'], 'student-abc');
      expect(json['photo_type'], 'before');
      expect(json['weight_kg'], 78.5);

      final restored = EvolutionPhoto.fromJson(json);
      expect(restored.id, photo.id);
      expect(restored.studentId, photo.studentId);
      expect(restored.photoType, 'before');
      expect(restored.caption, 'Foto inicial');
      expect(restored.weightKg, 78.5);
    });

    test('builds photo image widget for data URI safely', () {
      const dataUri = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      final widget = EvolutionPhotoService.buildPhotoImage(dataUri);
      expect(widget, isNotNull);
    });

    test('builds empty placeholder for blank photo url', () {
      final widget = EvolutionPhotoService.buildPhotoImage('');
      expect(widget, isNotNull);
    });
  });
}

