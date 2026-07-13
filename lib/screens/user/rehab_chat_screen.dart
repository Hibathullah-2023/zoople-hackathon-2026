import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../constants/app_colors.dart';
import '../../constants/kerala_locations.dart';
import '../../services/auth_service.dart';

/// Combined Rehabilitation screen featuring the AI Chatbot and the Nearby Centres Directory.
class RehabChatScreen extends StatefulWidget {
  const RehabChatScreen({super.key});

  @override
  State<RehabChatScreen> createState() => _RehabChatScreenState();
}

class _RehabChatScreenState extends State<RehabChatScreen> {
  String? _detectedDistrict;

  @override
  void initState() {
    super.initState();
    _detectCurrentDistrict();
  }

  Future<void> _detectCurrentDistrict() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position =
            await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low,
                timeLimit: Duration(seconds: 10),
              ),
            );
        List<Placemark> placemarks = [];
        try {
          placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
        } catch (_) {}

        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          final cleanSubAdmin = (pm.subAdministrativeArea ?? '').toLowerCase();
          final cleanLocality = (pm.locality ?? '').toLowerCase();

          for (final district in KeralaLocations.districts) {
            if (cleanSubAdmin.contains(district.toLowerCase()) ||
                cleanLocality.contains(district.toLowerCase()) ||
                (pm.administrativeArea ?? '').toLowerCase().contains(
                  district.toLowerCase(),
                )) {
              if (mounted) {
                setState(() {
                  _detectedDistrict = district;
                  _selectedDistrict = district;
                });
              }
              break;
            }
          }
        }
      }
    } catch (_) {}
  }

  // Chatbot State
  final List<Map<String, dynamic>> _messages = [
    {
      'sender': 'ai',
      'text':
          'Hello! I am your Nizhal Rehabilitation Assistant. I am here to listen, support, and share information on substance abuse recovery. How can I help you today?',
      'time': 'Just now',
    },
  ];
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final Map<String, String> _cannedResponses = {
    'help':
        'I can provide information on nearby rehabilitation centres, recovery advice, warning signs of addiction, or just offer a safe, anonymous space to chat. What is on your mind?',
    'hello':
        'Hello! Please know that you are not alone in this journey. I am here to help you find resources and motivation.',
    'hi':
        'Hello! Please know that you are not alone in this journey. I am here to help you find resources and motivation.',
    'rehab':
        'Rehabilitation centres provide structured therapy, detox support, and medical counseling. You can view a list of nearby centres by selecting the "Nearby Centres" tab above.',
    'support':
        'Seeking support is a very courageous first step. You can talk to family, contact professional counselors, or visit a registered de-addiction centre. We have listed verified Kerala centres in the directory tab.',
    'addiction':
        'Addiction is a complex condition, but recovery is absolutely possible. Professional treatment programs, behavioral therapy, and support groups like Narcotics Anonymous are highly effective.',
    'depressed':
        'I am sorry you are feeling this way. Recovery can be emotionally challenging. Please consider talking to a mental health professional or counselor. You can also reach out to Kerala de-addiction helplines.',
    'sad':
        'I hear you. It is okay to have difficult days. Remember to take things one step at a time. Professional guidance can help make this transition easier.',
    'thank':
        'You are very welcome! Nizhal is committed to supporting our community. Stay strong, and take care of yourself.',
    'thanks':
        'You are very welcome! Nizhal is committed to supporting our community. Stay strong, and take care of yourself.',
  };

  // Directory State
  String? _selectedDistrict;

  final List<Map<String, String>> _centres = [
    {
      'name': 'Government De-Addiction Centre, TVM',
      'district': 'Thiruvananthapuram',
      'city': 'Thiruvananthapuram',
      'address': 'General Hospital Campus, Thiruvananthapuram',
      'phone': '+914712307874',
    },
    {
      'name': 'Government De-addiction Centre, Ernakulam',
      'district': 'Ernakulam',
      'city': 'Kochi',
      'address': 'General Hospital, Ernakulam',
      'phone': '+914842361251',
    },
    {
      'name': 'Government De-addiction Centre, Kozhikode',
      'district': 'Kozhikode',
      'city': 'Kozhikode',
      'address': 'Mental Health Centre Campus, Kuthiravattom, Kozhikode',
      'phone': '+914952741385',
    },
    {
      'name': 'Government De-Addiction Centre, Thrissur',
      'district': 'Thrissur',
      'city': 'Thrissur',
      'address': 'District Hospital, Thrissur',
      'phone': '+914872333060',
    },
    {
      'name': 'Government De-Addiction Centre, Kollam',
      'district': 'Kollam',
      'city': 'Kollam',
      'address': 'District Hospital, Kollam',
      'phone': '+914742795017',
    },
    {
      'name': 'Government De-Addiction Centre, Palakkad',
      'district': 'Palakkad',
      'city': 'Palakkad',
      'address': 'District Hospital, Palakkad',
      'phone': '+914912534430',
    },
    {
      'name': 'Government De-Addiction Centre, Kannur',
      'district': 'Kannur',
      'city': 'Kannur',
      'address': 'District Hospital, Kannur',
      'phone': '+914972734342',
    },
    {
      'name': 'Punarnava De-Addiction Centre',
      'district': 'Kottayam',
      'city': 'Kottayam',
      'address': 'Medical College Road, Kottayam',
      'phone': '+914812563612',
    },
  ];

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text, 'time': 'Just now'});
      _messageController.clear();
    });

    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 1000), () {
      final responseText = _getAIResponse(text);
      if (mounted) {
        setState(() {
          _messages.add({
            'sender': 'ai',
            'text': responseText,
            'time': 'Just now',
          });
        });
        _scrollToBottom();
      }
    });
  }

  String _getAIResponse(String userInput) {
    final cleanInput = userInput.toLowerCase();
    for (final key in _cannedResponses.keys) {
      if (cleanInput.contains(key)) {
        return _cannedResponses[key]!;
      }
    }
    return 'Thank you for sharing. Recovering from substance abuse requires patience and professional support. I highly recommend reaching out to a local health professional or a rehabilitation center for personalized guidance. You are always welcome to check our "Nearby Centres" tab for contacts.';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _makeCall(String phone) async {
    final Uri url = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Rehabilitation Support'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.onSurfaceVariant),
              onPressed: () async {
                await authService.logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppColors.secondary,
            labelColor: AppColors.secondary,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            tabs: [
              Tab(icon: Icon(Icons.psychology), text: 'AI Chatbot'),
              Tab(icon: Icon(Icons.local_hospital), text: 'Nearby Centres'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ─── Tab 1: AI Chatbot ───
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: AppColors.surfaceContainerLow,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.onSurfaceVariant,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This assistant provides supportive info, not medical diagnosis or professional therapy.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['sender'] == 'user';
                      return _ChatBubble(
                        isUser: isUser,
                        text: msg['text'],
                        time: msg['time'],
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    border: Border(top: BorderSide(color: AppColors.divider)),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _messageController,
                            style: const TextStyle(color: AppColors.onSurface),
                            decoration: InputDecoration(
                              hintText: 'Ask about recovery, rehab, coping...',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              fillColor: AppColors.surfaceContainer,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onFieldSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _sendMessage,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.secondary,
                            ),
                            child: const Icon(
                              Icons.send,
                              color: AppColors.onSecondary,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ─── Tab 2: Nearby Centres ───
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedDistrict,
                    dropdownColor: AppColors.surfaceContainerHigh,
                    decoration: const InputDecoration(
                      labelText: 'Filter by District',
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Districts'),
                      ),
                      ...KeralaLocations.districts.map((d) {
                        return DropdownMenuItem<String>(
                          value: d,
                          child: Text(d),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedDistrict = val;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: () {
                    final List<Map<String, String>> sortedCentres =
                        List<Map<String, String>>.from(_centres)..sort((a, b) {
                          if (_detectedDistrict != null) {
                            final matchA = a['district'] == _detectedDistrict
                                ? 0
                                : 1;
                            final matchB = b['district'] == _detectedDistrict
                                ? 0
                                : 1;
                            return matchA.compareTo(matchB);
                          }
                          return 0;
                        });

                    final filteredCentres = _selectedDistrict == null
                        ? sortedCentres
                        : sortedCentres
                              .where((c) => c['district'] == _selectedDistrict)
                              .toList();

                    if (filteredCentres.isEmpty) {
                      return Center(
                        child: Text(
                          'No centres found in this district.',
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredCentres.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final centre = filteredCentres[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                centre['name']!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'District: ${centre['district']!} • ${centre['city']!}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                centre['address']!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.onSurfaceVariant.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _makeCall(centre['phone']!),
                                    icon: const Icon(Icons.phone, size: 16),
                                    label: const Text('Call Centre'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final bool isUser;
  final String text;
  final String time;

  const _ChatBubble({
    required this.isUser,
    required this.text,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.secondary.withValues(alpha: 0.15)
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(
            color: isUser
                ? AppColors.secondary.withValues(alpha: 0.3)
                : AppColors.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
