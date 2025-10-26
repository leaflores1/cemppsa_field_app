import 'package:flutter/material.dart';
import 'drafts_grid_screen.dart';
import 'sending_list_screen.dart';
import 'sent_list_screen.dart';

class PlanillasHubScreen extends StatelessWidget {
  const PlanillasHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis planillas'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.edit_document), text: 'Borradores'),
              Tab(icon: Icon(Icons.cloud_upload_outlined), text: 'Enviando'),
              Tab(icon: Icon(Icons.check_circle_outline), text: 'Enviadas'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DraftsGridScreen(),
            SendingListScreen(),
            SentListScreen(),
          ],
        ),
      ),
    );
  }
}
