class HistoryItem {
  final int id;
  final String itemType;

  // Attendance
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? checkInLocation;
  final String? checkOutLocation;
  final String? statusCheckIn;
  final String? statusCheckOut;

  // Leave Request
  final String? leaveType;
  final String reason;
  final String? status;
  
  // 🔥 DEKLARASI: Properti fileProof ditambahkan di sini
  final String? fileProof; 

  final DateTime? startDate;
  final DateTime? endDate;

  // Shared: Waktu Pengajuan (untuk cuti) atau Waktu Pencatatan (untuk absen)
  final DateTime createdAt;

  HistoryItem({
    required this.id,
    required this.itemType,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLocation,
    this.checkOutLocation,
    this.statusCheckIn,
    this.statusCheckOut,
    this.leaveType,
    this.reason = "Tidak ada alasan",
    this.status,
    // 🔥 INISIALISASI fileProof di Konstruktor
    this.fileProof, 
    this.startDate,
    this.endDate,
    required this.createdAt,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    bool isAttendance = json.containsKey('date') && !json.containsKey('type');

    // Asumsi: API mengirimkan 'created_at' di kedua tipe data
    final createdAtData =
        json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : (isAttendance && json['date'] != null
                ? DateTime.parse(json['date'])
                : DateTime.now()); // Fallback jika tidak ada created_at

    if (isAttendance) {
      return HistoryItem(
        id: json['id'],
        itemType: 'attendance',
        checkInTime:
            json['check_in_time'] != null
                ? DateTime.parse(json['check_in_time'])
                : null,
        checkOutTime:
            json['check_out_time'] != null
                ? DateTime.parse(json['check_out_time'])
                : null,
        checkInLocation: json['check_in_location'],
        checkOutLocation: json['check_out_location'],
        statusCheckIn: json['status_check_in'],
        statusCheckOut: json['status_check_out'],
        
        // fileProof, startDate, dan endDate dibiarkan null untuk Attendance

        // Menggunakan created_at dari API jika ada, atau fallback ke date
        createdAt: createdAtData,
      );
    } else {
      // Leave Request
      return HistoryItem(
        id: json['id'],
        itemType: 'leave_request',
        leaveType: json['type'],
        reason: json['reason'] ?? "Tidak ada alasan",
        status: json['status'],

        // 🔥 AMBIL DATA FILE PROOF
        fileProof: json['file_proof'], 
        
        // AMBIL TANGGAL CUTI/IZIN
        startDate:
            json['start_date'] != null
                ? DateTime.parse(json['start_date'])
                : null,
        endDate:
            json['end_date'] != null ? DateTime.parse(json['end_date']) : null,

        // Menggunakan created_at untuk waktu pengajuan
        createdAt: createdAtData,
      );
    }
  }
}