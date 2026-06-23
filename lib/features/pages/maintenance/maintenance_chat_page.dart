import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MaintenanceChatPage extends StatefulWidget {
  final String reportId;
  final String title;
  final bool isAdmin;

  const MaintenanceChatPage({Key? key, required this.reportId, required this.title, this.isAdmin = false}) : super(key: key);

  @override
  State<MaintenanceChatPage> createState() => _MaintenanceChatPageState();
}

class _MaintenanceChatPageState extends State<MaintenanceChatPage> {
  final TextEditingController _msgController = TextEditingController();
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? "ADMIN_UID";

  final Color _primaryColor = const Color(0xffF9A826);

  void _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;

    String msg = _msgController.text.trim();
    _msgController.clear();

    await FirebaseFirestore.instance
        .collection("maintenance_reports")
        .doc(widget.reportId)
        .collection("messages")
        .add({
      "senderId": _uid,
      "isAdmin": widget.isAdmin,
      "text": msg,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection("maintenance_reports").doc(widget.reportId).snapshots(),
            builder: (context, snapshot) {
              String unitNo = "";
              if (snapshot.hasData && snapshot.data!.data() != null) {
                unitNo = (snapshot.data!.data() as Map<String, dynamic>)['unit_no'] ?? "";
              }

              String mainTitle = widget.isAdmin
                  ? "Chat with Customer ${unitNo.isNotEmpty ? '($unitNo)' : ''}"
                  : "Chat with Admin";

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mainTitle, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(widget.title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              );
            }
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("maintenance_reports")
                  .doc(widget.reportId)
                  .collection("messages")
                  .orderBy("timestamp", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _primaryColor));
                var docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Center(child: Text("No messages yet.\nStart the conversation!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == _uid;

                    Timestamp? ts = data['timestamp'] as Timestamp?;
                    String timeString = "Just now";
                    if (ts != null) {
                      timeString = DateFormat('HH:mm').format(ts.toDate());
                    }

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? _primaryColor : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(0),
                            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
                          ),
                          border: isMe ? null : Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              data['text'] ?? '',
                              style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeString,
                              style: TextStyle(
                                color: isMe ? Colors.white70 : Colors.grey.shade500,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    cursorColor: _primaryColor,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: _primaryColor, width: 1.5)),
                      filled: true, fillColor: Colors.grey.shade100,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _primaryColor,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}