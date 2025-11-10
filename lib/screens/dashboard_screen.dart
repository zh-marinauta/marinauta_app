import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'coleta_screen.dart';
import 'embarcacao_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String nome = '';
  String municipio = '';
  String entreposto = '';
  int totalDesembarques = 0;
  int totalDesembarquesMes = 0;
  int totalEmbarcacoes = 0;
  int totalEmbarcacoesMes = 0;
  bool loading = true;

  final Map<String, List<String>> entrepostosPorMunicipio = {
    'Paranaguá': ['Mercado do Peixe', 'Vila Guarani'],
    'Pontal do Paraná': ['Pontal Sul'],
    'Antonina': ['Ponta da Pita', 'Praia dos Polacos', 'Mercado de Antonina'],
    'Morretes': ['Centro', 'Porto de Cima'],
  };

  final List<String> municipios = [
    'Paranaguá',
    'Pontal do Paraná',
    'Guaraqueçaba',
    'Antonina',
    'Morretes'
  ];

  List<String> entrepostosFiltrados = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      setState(() => loading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('coletores')
          .doc(user.email)
          .get();

      if (!doc.exists) throw Exception('Coletor não encontrado.');

      final data = doc.data() ?? {};
      final now = DateTime.now();

      final desembarquesSnap = await FirebaseFirestore.instance
          .collection('desembarques')
          .where('coletor', isEqualTo: user.email)
          .get();

      final embarcacoesSnap = await FirebaseFirestore.instance
          .collection('embarcacoes')
          .where('coletor', isEqualTo: user.email)
          .get();

      setState(() {
        nome = data['nome'] ?? user.email!;
        municipio = data['municipio'] ?? '';
        entreposto = data['entreposto'] ?? '';
        entrepostosFiltrados = entrepostosPorMunicipio[municipio] ?? [];

        totalDesembarques = desembarquesSnap.size;
        totalEmbarcacoes = embarcacoesSnap.size;

        totalDesembarquesMes = desembarquesSnap.docs
            .where((doc) => (doc['data'] ?? '')
                .toString()
                .contains('/${now.month.toString().padLeft(2, '0')}/'))
            .length;

        totalEmbarcacoesMes = embarcacoesSnap.docs
            .where((doc) => (doc['data_cadastro'] ?? '')
                .toString()
                .contains('/${now.month.toString().padLeft(2, '0')}/'))
            .length;

        loading = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados atualizados com sucesso.')),
        );
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
      setState(() => loading = false);
    }
  }

  Future<void> _atualizarCampo(String campo, String valor) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('coletores')
            .doc(user.email)
            .update({campo: valor});
      }
    } catch (e) {
      debugPrint('Erro ao atualizar $campo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final azul = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do Coletor'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: azul),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: azul,
            tooltip: 'Atualizar dados',
            onPressed: () async {
              await _carregarDados();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            color: azul,
            tooltip: 'Sair',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: loading
          ? Center(
              child: CircularProgressIndicator(color: azul),
            )
          : RefreshIndicator(
              onRefresh: _carregarDados,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/logo_marinauta.png',
                        height: 80,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Olá, $nome 👋',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: azul,
                          ),
                    ),
                    const SizedBox(height: 24),

                    // MUNICÍPIO
                    DropdownButtonFormField<String>(
                      value: municipios.contains(municipio) ? municipio : null,
                      decoration: InputDecoration(
                        labelText: 'Município',
                        labelStyle: TextStyle(color: azul),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: azul, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: azul, width: 1.5),
                        ),
                      ),
                      items: municipios
                          .map((m) =>
                              DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            municipio = value;
                            entreposto = '';
                            entrepostosFiltrados =
                                entrepostosPorMunicipio[value] ?? [];
                          });
                          _atualizarCampo('municipio', value);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // ENTREPOSTO
                    DropdownButtonFormField<String>(
                      value: entrepostosFiltrados.contains(entreposto)
                          ? entreposto
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Entreposto',
                        labelStyle: TextStyle(color: azul),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: azul, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: azul, width: 1.5),
                        ),
                      ),
                      items: entrepostosFiltrados
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => entreposto = value);
                          _atualizarCampo('entreposto', value);
                        }
                      },
                    ),

                    const SizedBox(height: 30),

                    // CARDS DE INFORMAÇÕES
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _infoCardDouble(
                            title: 'Desembarques Registrados',
                            mes: totalDesembarquesMes.toString(),
                            total: totalDesembarques.toString(),
                            icon: Icons.assignment,
                          ),
                          const SizedBox(height: 16),
                          _infoCardDouble(
                            title: 'Embarcações Cadastradas',
                            mes: totalEmbarcacoesMes.toString(),
                            total: totalEmbarcacoes.toString(),
                            icon: Icons.directions_boat,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // BOTÕES DE AÇÃO
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ColetaScreen(
                              coletorEmail:
                                  FirebaseAuth.instance.currentUser?.email ?? '',
                              municipio: municipio,
                              entreposto: entreposto,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Novo Registro de Desembarque'),
                    ),

                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EmbarcacaoScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.directions_boat),
                      label: const Text('Cadastrar Embarcação'),
                    ),

                    const SizedBox(height: 40),
                    const Center(
                      child: Text(
                        'Marinauta - 24h Sea Works & Marine Science Services',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _infoCardDouble({
    required String title,
    required String mes,
    required String total,
    required IconData icon,
  }) {
    final azul = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: azul, size: 28),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                color: azul,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Mês Atual: $mes',
                style: TextStyle(color: azul, fontSize: 14)),
            Text('Total: $total',
                style: TextStyle(color: azul, fontSize: 14)),
          ],
        ),
      ],
    );
  }
}
