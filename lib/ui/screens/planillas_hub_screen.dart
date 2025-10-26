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
          leading: const BackButton(), // icono de volver explícito
          title: const Text('Mis planillas'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.edit_note),        text: 'Borradores'), // compat
              Tab(icon: Icon(Icons.cloud_upload),     text: 'Enviando'),   // compat
              Tab(icon: Icon(Icons.check_circle),     text: 'Enviadas'),   // compat
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
        floatingActionButton: FloatingActionButton(
          tooltip: 'Crear planilla',
          onPressed: () {
            // Dejamos la creación en el Home (donde está Repo/Provider a mano),
            // o podrías inyectar repo aquí también y navegar al formulario.
            Navigator.pop(context); // Volvemos al Home para crear desde allí, o…
            // … si prefieres crear aquí, avísame y te paso la versión con Provider.
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
