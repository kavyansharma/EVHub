import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import 'dart:ui';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandColor = theme.colorScheme.primary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: AppColors.background.withOpacity(0.5)),
          ),
        ),
        title: const Text('EV Community', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [brandColor.withOpacity(0.15), AppColors.background],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8, left: 24),
                  child: Text('Top Contributors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brandColor)),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildLeaderboard(),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 16, left: 24),
                  child: const Text('Trending Now', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildPostCard(index, brandColor);
                  },
                  childCount: 3,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: brandColor,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Widget _buildLeaderboard() {
    final users = [
      {'name': 'Rahul S.', 'points': '4.2k', 'avatar': 'https://i.pravatar.cc/150?img=11'},
      {'name': 'Priya M.', 'points': '3.8k', 'avatar': 'https://i.pravatar.cc/150?img=5'},
      {'name': 'Amit K.', 'points': '2.9k', 'avatar': 'https://i.pravatar.cc/150?img=12'},
      {'name': 'Neha R.', 'points': '2.1k', 'avatar': 'https://i.pravatar.cc/150?img=9'},
    ];

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: index == 0 ? [Colors.amber, Colors.orange] : [Colors.blue, Colors.purple],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 35,
                    backgroundImage: NetworkImage(user['avatar']!),
                  ),
                ),
                const SizedBox(height: 8),
                Text(user['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text('${user['points']} pts', style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostCard(int index, Color brandColor) {
    final posts = [
      {
        'user': 'Vikram Singh',
        'avatar': 'https://i.pravatar.cc/150?img=33',
        'time': '2 hours ago',
        'content': 'Just tested the new 150kW fast charger at Statiq CP. Went from 20% to 80% in just 25 minutes! Highly recommend stopping here if you are on the highway.',
        'image': 'https://images.unsplash.com/photo-1593941707882-a5bba14938cb?auto=format&fit=crop&w=800&q=80',
        'likes': '245',
        'comments': '42',
      },
      {
        'user': 'Anjali Gupta',
        'avatar': 'https://i.pravatar.cc/150?img=44',
        'time': '5 hours ago',
        'content': 'Taking my Nexon EV for a weekend trip to Jaipur. The Smart Route Planner suggested perfect stops. No range anxiety!',
        'image': null,
        'likes': '128',
        'comments': '15',
      },
      {
        'user': 'Rajesh Sharma',
        'avatar': 'https://i.pravatar.cc/150?img=55',
        'time': '1 day ago',
        'content': 'Finally hit 50,000 km on my MG ZS EV. Battery health is still at 98%. EVs are the future.',
        'image': 'https://images.unsplash.com/photo-1620891549027-942fdc95d3f5?auto=format&fit=crop&w=800&q=80',
        'likes': '512',
        'comments': '89',
      },
    ];

    final post = posts[index];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: GlassContainer(
        padding: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(radius: 20, backgroundImage: NetworkImage(post['avatar']!)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post['user']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(post['time']!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.more_horiz, color: Colors.grey), onPressed: () {}),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(post['content']!, style: const TextStyle(fontSize: 15, height: 1.4)),
            ),
            const SizedBox(height: 12),
            if (post['image'] != null)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(image: NetworkImage(post['image']!), fit: BoxFit.cover),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  _buildInteractionBtn(Icons.thumb_up_alt_outlined, post['likes']!, brandColor),
                  const SizedBox(width: 24),
                  _buildInteractionBtn(Icons.comment_outlined, post['comments']!, Colors.grey),
                  const Spacer(),
                  _buildInteractionBtn(Icons.share_outlined, 'Share', Colors.grey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionBtn(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
