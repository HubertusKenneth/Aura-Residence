import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/home_carousel_banner.dart';

class GuestPage extends StatelessWidget {
  final String userName;
  final bool hasPending;
  final QueryDocumentSnapshot? pendingDoc;

  final Widget greetingWidget;

  final VoidCallback onRentUnitTap;
  final VoidCallback onLinkUnitTap;
  final Function(String) onCancelRequestTap;

  const GuestPage({
    Key? key,
    required this.userName,
    required this.hasPending,
    this.pendingDoc,
    required this.greetingWidget,
    required this.onRentUnitTap,
    required this.onLinkUnitTap,
    required this.onCancelRequestTap,
  }) : super(key: key);

  Widget _buildUserGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        greetingWidget,
        const SizedBox(height: 2),
        Text(
          userName,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.indigo.shade700, letterSpacing: 0.3),
        ),
      ],
    );
  }

  Widget _buildNewFacilityIcon(IconData icon, String title, String subtitle, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 2),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBottomFeature(IconData icon, String title, String subtitle, Color color) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 9, color: Colors.grey, height: 1.3)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String title, String subtitle, Color iconBg, Color iconColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedTopSection(String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            const CarouselBanner(),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 30,
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30))
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserGreeting(),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 15),
                Text(description, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5)),
              ]
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSharedFacilitiesHighlight() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNewFacilityIcon(Icons.shield_outlined, "24/7 Security", "Always safe", Colors.blue),
          _buildNewFacilityIcon(Icons.pool, "Swimming Pool", "Relax & refresh", Colors.teal),
          _buildNewFacilityIcon(Icons.fitness_center, "Gym Center", "Stay healthy", Colors.orange),
          _buildNewFacilityIcon(Icons.local_parking, "Spacious Parking", "Easy & secure", Colors.purple),
        ],
      ),
    );
  }

  Widget _buildSharedBottomFeatures() {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 40),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xffFFFDF8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.orange.shade50)
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBottomFeature(Icons.stars, "Premium Living", "Top-notch facilities\nfor your comfort", Colors.orange),
          _buildBottomFeature(Icons.person_outline, "Professional\nManagement", "We're here to serve\nyou better", Colors.purple),
          _buildBottomFeature(Icons.support_agent, "24/7 Support", "Assistance anytime,\nanywhere", Colors.green),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (hasPending && pendingDoc != null) {
      var data = pendingDoc!.data() as Map<String, dynamic>;
      String transType = data['transaction_type'] ?? 'Link Unit';
      String reqTypeDisplay = transType.contains('Rent') ? 'Rent Unit' : 'Link Unit';
      Timestamp? ts = data['timestamp'] as Timestamp?;
      String dateDisplay = ts != null ? DateFormat('dd MMM yyyy, HH:mm').format(ts.toDate()) : '-';

      return SingleChildScrollView(
        child: Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSharedTopSection("Find your perfect unit and enjoy premium living with amazing facilities."),
              _buildSharedFacilitiesHighlight(),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xffFFFDF8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange.shade100, shape: BoxShape.circle),
                      child: Icon(Icons.hourglass_empty, color: Colors.orange.shade600, size: 28),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Text("Pending Approval", style: TextStyle(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Request in Progress", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                              const SizedBox(height: 10),
                              Text("Your request is being reviewed by the management. This usually takes less than 24 hours.", style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.5)),
                            ],
                          ),
                        ),
                        Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Image.asset('assets/images/Email1.png', height: 100),
                            )
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))]
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: Row(
                                    children: [
                                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle), child: Icon(Icons.domain, color: Colors.orange.shade400, size: 18)),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("Request Type", style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          Text(reqTypeDisplay, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                                        ],
                                      )
                                    ],
                                  )
                              ),
                              Container(height: 35, width: 1, color: Colors.grey.shade200),
                              const SizedBox(width: 15),
                              Expanded(
                                  child: Row(
                                    children: [
                                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle), child: Icon(Icons.calendar_today, color: Colors.orange.shade400, size: 18)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text("Submitted On", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                                            Text(dateDisplay, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87), overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      )
                                    ],
                                  )
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.orange.shade100)
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.orange.shade500, size: 18),
                                const SizedBox(width: 10),
                                const Expanded(child: Text("You will receive a notification once your request has been reviewed.", style: TextStyle(fontSize: 11, color: Colors.black54))),
                              ],
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("What can you do now?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 15),
                    _buildActionCard(Icons.cancel_outlined, "Cancel Request", "Cancel your current request if needed.", Colors.red.shade50, Colors.red.shade400, () => onCancelRequestTap(pendingDoc!.id)),
                    const SizedBox(height: 25),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xffF4F8FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.blue.shade100, shape: BoxShape.circle),
                            child: Icon(Icons.lock_outline, color: Colors.blue.shade600, size: 24),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Why can't I make another request?", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                                const SizedBox(height: 5),
                                Text("You can only have one active request at a time. Once this request is completed, you'll be able to create a new one.", style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4)),
                              ],
                            ),
                          ),
                          Icon(Icons.verified_user, size: 50, color: Colors.blue.shade100)
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildSharedBottomFeatures(),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSharedTopSection("Find your perfect unit and enjoy premium living with amazing facilities."),
            _buildSharedFacilitiesHighlight(),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))]
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                          child: Icon(Icons.domain, color: Colors.orange.shade700, size: 20),
                        ),
                        const SizedBox(height: 12),
                        const Text("Ready to move in?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 8),
                        Text("Explore available units and start your comfortable living experience today.", style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xffF9A826),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                          ),
                          onPressed: onRentUnitTap,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text("View Available Units", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                              SizedBox(width: 4),
                              Icon(Icons.chevron_right, size: 16, color: Colors.white)
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Image.asset('assets/images/Email1.png', fit: BoxFit.contain, height: 100),
                      )
                  )
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: const Color(0xffF4F8FF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.blue.shade50, width: 2)
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.blue.shade100, shape: BoxShape.circle),
                          child: Icon(Icons.vpn_key, color: Colors.blue.shade700, size: 20),
                        ),
                        const SizedBox(height: 12),
                        const Text("Already have a unit?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 8),
                        Text("Purchased or rented a unit offline? Link your account to access your unit.", style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue.shade700,
                              side: BorderSide(color: Colors.blue.shade400, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                          ),
                          onPressed: onLinkUnitTap,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text("Link My Unit", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              SizedBox(width: 4),
                              Icon(Icons.chevron_right, size: 16)
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Icon(Icons.meeting_room, size: 90, color: Colors.blue.shade200),
                    ),
                  )
                ],
              ),
            ),
            _buildSharedBottomFeatures(),
          ],
        ),
      ),
    );
  }
}