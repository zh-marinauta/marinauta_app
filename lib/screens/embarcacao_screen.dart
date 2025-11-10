import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmbarcacaoScreen extends StatefulWidget {
  const EmbarcacaoScreen({Key? key}) : super(key: key);

  @override
  State<EmbarcacaoScreen> createState() => _EmbarcacaoScreenState();
}

class _EmbarcacaoScreenState extends State<EmbarcacaoScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _registroController = TextEditingController();
  final _comprimentoController = TextEditingController();
  final _potenciaController = TextEditingController();
  final _materialController = TextEditingController();

  bool _salvando = false;

  Future<void> _salvarEmbarcacao() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _salvando = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('embarcacoes').add({
        'coletor': user.email,
        'nome_embarcacao': _nomeController.text.trim(),
        'registro': _registroController.text.trim(),
        'comprimento': double.tryParse(_comprimentoController.text) ?? 0.0,
        'potencia_motor': double.tryParse(_potenciaController.text) ?? 0.0,
        'material': _materialController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Embarcação cadastrada com sucesso!')),
        );
        Navigator.pop(context); // volta ao dashboard
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    } finally {
      setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00294D),
      appBar: AppBar(
        title: const Text('Cadastrar Embarcação'),
        backgroundColor: const Color(0xFF001F3D),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _campoTexto('Nome da Embarcação', _nomeController),
              const SizedBox(height: 16),
              _campoTexto('Registro (número ou identificação)', _registroController),
              const SizedBox(height: 16),
              _campoTexto('Comprimento (m)', _comprimentoController,
                  tipo: TextInputType.number),
              const SizedBox(height: 16),
              _campoTexto('Potência do Motor (HP)', _potenciaController,
                  tipo: TextInputType.number),
              const SizedBox(height: 16),
              _campoTexto('Material do Casco (madeira, fibra, alumínio...)',
                  _materialController),
              const SizedBox(height: 32),
              _salvando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : ElevatedButton.icon(
                      onPressed: _salvarEmbarcacao,
                      icon: const Icon(Icons.save),
                      label: const Text(
                        'Salvar Embarcação',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF00294D),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campoTexto(String label, TextEditingController controller,
      {TextInputType tipo = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: tipo,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white38),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: (value) =>
          (value == null || value.isEmpty) ? 'Campo obrigatório' : null,
    );
  }
}

