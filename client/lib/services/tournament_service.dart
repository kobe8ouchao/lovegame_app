import 'package:dio/dio.dart';
import '../models/tournament_model.dart';

class TournamentService {
  final Dio _dio = Dio();
  final String _baseUrl = 'http://localhost:5000'; // Change to your backend URL

  TournamentService() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<List<Tournament>> getTournaments() async {
    try {
      final response = await _dio.get('/api/tournaments');
      final List<dynamic> data = response.data;
      return data.map((item) => Tournament.fromJson(item)).toList();
    } catch (e) {
      print('Error fetching tournaments: $e');
      return _getMockTournaments(); // In production, you'd handle this differently
    }
  }

  Future<List<Tournament>> getTournamentsByMonth(int year, int month) async {
    try {
      final response = await _dio.get('/api/tournaments/month/$year/$month');
      final List<dynamic> data = response.data;
      return data.map((item) => Tournament.fromJson(item)).toList();
    } catch (e) {
      print('Error fetching tournaments by month: $e');
      return _getMockTournaments().where((tournament) {
        return tournament.startDate.year == year && 
               (tournament.startDate.month == month || tournament.endDate.month == month);
      }).toList();
    }
  }

  // Mock data for testing
  List<Tournament> _getMockTournaments() {
    final currentYear = DateTime.now().year;
    return [
      Tournament(
        id: '1',
        name: 'Porsche Tennis Grand Prix',
        location: 'Stuttgart, Germany',
        startDate: DateTime(currentYear, 4, 14),
        endDate: DateTime(currentYear, 4, 21),
        category: 'WTA 500',
        surface: 'Clay',
        countryCode: 'DEU',
        logoUrl: 'https://example.com/porsche.png',
      ),
      Tournament(
        id: '2',
        name: 'Mutua Madrid Open',
        location: 'Madrid, Spain',
        startDate: DateTime(currentYear, 4, 22),
        endDate: DateTime(currentYear, 5, 4),
        category: 'WTA 1000',
        surface: 'Clay',
        countryCode: 'ESP',
        logoUrl: 'https://example.com/madrid.png',
      ),
      Tournament(
        id: '3',
        name: 'Internazionali BNL d\'Italia',
        location: 'Rome, Italy',
        startDate: DateTime(currentYear, 5, 6),
        endDate: DateTime(currentYear, 5, 18),
        category: 'WTA 1000',
        surface: 'Clay',
        countryCode: 'ITA',
        logoUrl: 'https://example.com/rome.png',
      ),
      Tournament(
        id: '4',
        name: 'Internationaux de Strasbourg',
        location: 'Strasbourg, France',
        startDate: DateTime(currentYear, 5, 18),
        endDate: DateTime(currentYear, 5, 24),
        category: 'WTA 500',
        surface: 'Clay',
        countryCode: 'FRA',
        logoUrl: 'https://example.com/strasbourg.png',
      ),
      Tournament(
        id: '5',
        name: 'Roland Garros',
        location: 'Paris, France',
        startDate: DateTime(currentYear, 5, 25),
        endDate: DateTime(currentYear, 6, 8),
        category: 'Grand Slam',
        surface: 'Clay',
        countryCode: 'FRA',
        logoUrl: 'https://example.com/rolandgarros.png',
      ),
    ];
  }
} 