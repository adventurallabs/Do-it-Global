
enum MessageType { text, leaveRequest, infoLate, infoLeave, document }

enum LeaveStatus { requested, review, granted, rejected }

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime createdAt;
  final MessageType type;
  final LeaveRequest? leaveRequest;
  final String? attachmentName;
  final int? attachmentSize; // in bytes

  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.createdAt,
    this.type = MessageType.text,
    this.leaveRequest,
    this.attachmentName,
    this.attachmentSize,
  });

  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? text,
    DateTime? createdAt,
    MessageType? type,
    LeaveRequest? leaveRequest,
    String? attachmentName,
    int? attachmentSize,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      leaveRequest: leaveRequest ?? this.leaveRequest,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentSize: attachmentSize ?? this.attachmentSize,
    );
  }
}

class LeaveRequest {
  final String id;
  final String reason;
  final int duration;
  final DateTime? date;
  final DateTime? fromDate;
  final DateTime? toDate;
  final LeaveStatus status;
  final DateTime createdAt;

  const LeaveRequest({
    required this.id,
    required this.reason,
    required this.duration,
    this.date,
    this.fromDate,
    this.toDate,
    this.status = LeaveStatus.requested,
    required this.createdAt,
  });

  LeaveRequest copyWith({
    String? id,
    String? reason,
    int? duration,
    DateTime? date,
    DateTime? fromDate,
    DateTime? toDate,
    LeaveStatus? status,
    DateTime? createdAt,
  }) {
    return LeaveRequest(
      id: id ?? this.id,
      reason: reason ?? this.reason,
      duration: duration ?? this.duration,
      date: date ?? this.date,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
