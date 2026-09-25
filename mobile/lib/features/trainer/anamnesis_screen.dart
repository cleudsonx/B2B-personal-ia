import 'package:flutter/material.dart';
import '../../models/workout_plan_model.dart';
import '../../services/api_service.dart';

class TrainerAnamnesisScreen extends StatefulWidget {
  const TrainerAnamnesisScreen({super.key});

  @override
  State<TrainerAnamnesisScreen> createState() => _TrainerAnamnesisScreenState();
}

class _TrainerAnamnesisScreenState extends State<TrainerAnamnesisScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  String _objective = 'Hipertrofia Muscular';
  String _trainingLevel = 'Intermediário';
  int _daysPerWeek = 4;
  String _workoutLocation = 'Academia completa';
  final _restrictionsCtrl = TextEditingController(
    text: 'Leve desconforto no ombro direito (evitar abdução acima de 90° com carga pesada)',
  );
  final _notesCtrl = TextEditingController(
    text: 'Foco em peitoral superior e deltoides',
  );

  bool _isLoading = false;
  WorkoutPlanModel? _generatedPlan;

  @override
  void dispose() {
    _restrictionsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleGenerate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final plan = await _apiService.generateWorkoutPlan(
        objective: _objective,
        trainingLevel: _trainingLevel,
        daysPerWeek: _daysPerWeek,
        workoutLocation: _workoutLocation,
        injuriesOrRestrictions: _restrictionsCtrl.text,
        additionalNotes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      );

      setState(() {
        _generatedPlan = plan;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Periodização gerada com sucesso pela IA!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Erro ao gerar periodização: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_generatedPlan == null ? 'Nova Anamnese & Ficha' : 'Revisão da Ficha'),
        actions: [
          if (_generatedPlan != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recomeçar',
              onPressed: () => setState(() => _generatedPlan = null),
            ),
        ],
      ),
      body: Stack(
        children: [
          _generatedPlan == null ? _buildForm() : _buildPlanReviewer(_generatedPlan!),
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Calculando volume e biomecânica com IA...',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Parâmetros do Aluno',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _objective,
            decoration: const InputDecoration(
              labelText: 'Objetivo Principal',
              border: OutlineInputBorder(),
            ),
            items: ['Hipertrofia Muscular', 'Emagrecimento', 'Condicionamento Geral', 'Força Máxima']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _objective = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _trainingLevel,
            decoration: const InputDecoration(
              labelText: 'Nível de Treino',
              border: OutlineInputBorder(),
            ),
            items: ['Iniciante', 'Intermediário', 'Avançado']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _trainingLevel = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _daysPerWeek,
            decoration: const InputDecoration(
              labelText: 'Frequência Semanal (Dias/Semana)',
              border: OutlineInputBorder(),
            ),
            items: [2, 3, 4, 5, 6].map((e) => DropdownMenuItem(value: e, child: Text('$e dias'))).toList(),
            onChanged: (val) => setState(() => _daysPerWeek = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _workoutLocation,
            decoration: const InputDecoration(
              labelText: 'Ambiente de Treino',
              border: OutlineInputBorder(),
            ),
            items: ['Academia completa', 'Condomínio', 'Em casa (Halteres/Peso Corporal)']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _workoutLocation = val!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _restrictionsCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Dores, Lesões e Restrições Articulares',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Observações / Preferências do Treinador',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Gerar Periodização com IA'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: _handleGenerate,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanReviewer(WorkoutPlanModel plan) {
    return DefaultTabController(
      length: plan.splits.length,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.workoutPlanTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Diretriz da IA: ${plan.notesForTrainer}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          TabBar(
            isScrollable: true,
            labelColor: Theme.of(context).primaryColor,
            tabs: plan.splits
                .map((s) => Tab(text: 'Treino ${s.splitIdentifier} (${s.splitName})'))
                .toList(),
          ),
          Expanded(
            child: TabBarView(
              children: plan.splits.map((split) {
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: split.exercises.length,
                  itemBuilder: (ctx, i) {
                    final ex = split.exercises[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${ex.order}')),
                        title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${ex.sets} séries x ${ex.reps} | Descanso: ${ex.restSeconds}s\n${ex.notes}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Aprovar e Liberar para o Aluno'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ficha aprovada e sincronizada com sucesso!')),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
