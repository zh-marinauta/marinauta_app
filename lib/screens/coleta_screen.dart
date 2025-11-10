import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ColetaScreen extends StatefulWidget {
  final String coletorEmail;
  final String municipio;
  final String entreposto;

  const ColetaScreen({
    super.key,
    required this.coletorEmail,
    required this.municipio,
    required this.entreposto,
  });

  @override
  State<ColetaScreen> createState() => _ColetaScreenState();
}

class _ColetaScreenState extends State<ColetaScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controladores gerais
  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _horaController = TextEditingController();
  final TextEditingController _localController = TextEditingController();

  // Unidade Produtiva
  final TextEditingController _buscaUnidadeController = TextEditingController();
  final TextEditingController _pescadorController = TextEditingController();
  final TextEditingController _embarcacaoController = TextEditingController();
  final TextEditingController _tipoEmbarcacaoController = TextEditingController();
  final TextEditingController _categoriaEmbarcacaoController = TextEditingController();
  final TextEditingController _comunidadeController = TextEditingController();

  // 🔹 Adiciona uma espécie à lista local
void _adicionarEspecie(Map<String, dynamic> especie) {
  setState(() {
    especiesRegistradas.add(especie);
  });
}

// 🔹 Remove uma espécie da lista local
void _removerEspecie(int index) {
  setState(() {
    especiesRegistradas.removeAt(index);
  });
}


  String? unidadeProdutivaSelecionada;
  String origemProducao = "Própria";
  List<Map<String, dynamic>> especiesRegistradas = [];
  List<Map<String, dynamic>> sugestoesUnidades = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dataController.text = DateFormat('dd/MM/yyyy').format(now);
    _horaController.text = DateFormat('HH:mm').format(now);
    _localController.text = widget.entreposto;
  }

  // 🔹 Busca unidades produtivas existentes no Firestore
  Future<void> _buscarUnidadesProdutivas(String termo) async {
    if (termo.length < 3) return; // Evita buscar com menos de 3 letras
    final query = await _firestore
        .collection('unidades_produtivas')
        .where('ativo', isEqualTo: true)
        .get();

    final resultados = query.docs
        .where((d) => d['unidade_produtiva']
            .toString()
            .toLowerCase()
            .contains(termo.toLowerCase()))
        .map((d) => {
              'id': d.id,
              ...d.data(),
            })
        .toList();

    setState(() {
      sugestoesUnidades = resultados.cast<Map<String, dynamic>>();
    });
  }

  // 🔹 Preenche os campos com base na unidade selecionada
  void _selecionarUnidade(Map<String, dynamic> unidade) {
    setState(() {
      unidadeProdutivaSelecionada = unidade['unidade_produtiva'];
      _buscaUnidadeController.text = unidade['unidade_produtiva'];
      _pescadorController.text = unidade['pescador'] ?? '';
      _embarcacaoController.text = unidade['embarcacao'] ?? '';
      _tipoEmbarcacaoController.text = unidade['tipo_embarcacao'] ?? '';
      _categoriaEmbarcacaoController.text = unidade['categoria_embarcacao'] ?? '';
      _comunidadeController.text = unidade['comunidade'] ?? '';
      sugestoesUnidades.clear();
    });
  }

  // 🔹 Gera ou recupera uma unidade produtiva existente
  Future<void> _salvarUnidadeProdutiva() async {
    final nome = _pescadorController.text.trim();
    final barco = _embarcacaoController.text.trim();
    final tipo = _tipoEmbarcacaoController.text.trim();
    final categoria = _categoriaEmbarcacaoController.text.trim();
    final comunidade = _comunidadeController.text.trim();

    final unidade = "$nome - $barco - $comunidade - $tipo - $categoria";

    final query = await _firestore
        .collection('unidades_produtivas')
        .where('unidade_produtiva', isEqualTo: unidade)
        .get();

    if (query.docs.isEmpty) {
      await _firestore.collection('unidades_produtivas').add({
        'unidade_produtiva': unidade,
        'pescador': nome,
        'embarcacao': barco,
        'tipo_embarcacao': tipo,
        'categoria_embarcacao': categoria,
        'comunidade': comunidade,
        'municipio': widget.municipio,
        'entrepostos': [widget.entreposto],
        'ativo': true,
        'busca': [nome, barco, comunidade, tipo, categoria]
            .map((e) => e.toLowerCase())
            .toList(),
      });
    }

    unidadeProdutivaSelecionada = unidade;
  }

  // 🔹 Salva o desembarque completo
  Future<void> _salvarDesembarque() async {
    if (especiesRegistradas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione ao menos uma espécie.')),
      );
      return;
    }

    await _salvarUnidadeProdutiva();

    final novoDesembarque = {
      'data': _dataController.text,
      'hora': _horaController.text,
      'coletor': widget.coletorEmail,
      'municipio': widget.municipio,
      'entreposto': widget.entreposto,
      'local': _localController.text,
      'unidade_produtiva': unidadeProdutivaSelecionada,
      'pescador': _pescadorController.text,
      'embarcacao': _embarcacaoController.text,
      'tipo_embarcacao': _tipoEmbarcacaoController.text,
      'categoria_embarcacao': _categoriaEmbarcacaoController.text,
      'comunidade': _comunidadeController.text,
      'origem_producao': origemProducao,
      'timestamp': DateTime.now().toIso8601String(),
      'especies': especiesRegistradas,
    };

    await _firestore.collection('desembarques').add(novoDesembarque);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Desembarque salvo com sucesso!')),
    );

    await Future.delayed(const Duration(seconds: 1));
    if (context.mounted) Navigator.pushReplacementNamed(context, '/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    const azul = Color(0xFF00294D);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: azul,
        title: const Text('Registro de Desembarque'),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔍 Campo de busca por unidade produtiva
            Text('Buscar Unidade Produtiva',
                style: TextStyle(color: azul, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _buscaUnidadeController,
              style: TextStyle(color: azul),
              decoration: InputDecoration(
                labelText: 'Digite parte do nome, barco ou comunidade',
                labelStyle: TextStyle(color: azul),
                focusedBorder:
                    OutlineInputBorder(borderSide: BorderSide(color: azul)),
                enabledBorder:
                    OutlineInputBorder(borderSide: BorderSide(color: azul)),
              ),
              onChanged: _buscarUnidadesProdutivas,
            ),
            if (sugestoesUnidades.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: azul),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Column(
                  children: sugestoesUnidades
                      .map((u) => ListTile(
                            title: Text(u['unidade_produtiva'],
                                style: TextStyle(color: azul)),
                            onTap: () => _selecionarUnidade(u),
                          ))
                      .toList(),
                ),
              ),

            const SizedBox(height: 16),

            // Unidade produtiva - campos
            Text('Dados da Unidade Produtiva',
                style: TextStyle(color: azul, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildTextField('Pescador', _pescadorController, azul),
            const SizedBox(height: 8),
            _buildTextField('Embarcação', _embarcacaoController, azul),
            const SizedBox(height: 8),
            _buildTextField('Tipo de embarcação', _tipoEmbarcacaoController, azul),
            const SizedBox(height: 8),
            _buildTextField('Categoria da embarcação', _categoriaEmbarcacaoController, azul),
            const SizedBox(height: 8),
            _buildTextField('Comunidade', _comunidadeController, azul),

            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: origemProducao,
              items: ['Própria', 'De terceiros', 'Ambas']
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              decoration: InputDecoration(
                labelText: 'Origem da produção',
                labelStyle: TextStyle(color: azul),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: azul)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: azul)),
              ),
              onChanged: (v) => setState(() => origemProducao = v!),
            ),

            const Divider(height: 24, color: Colors.black26),

            // Espécies
            ...especiesRegistradas.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text('${e['especie']} - ${e['quantidade']} ${e['unidade']}',
                      style: TextStyle(color: azul)),
                  subtitle:
                      Text('Pesqueiro: ${e['pesqueiro']} | R\$${e['preco_unidade']}/un'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removerEspecie(i),
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _mostrarDialogoAdicionarEspecie(context),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Espécie'),
            ),

            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _salvarDesembarque,
                style: ElevatedButton.styleFrom(backgroundColor: azul),
                child: const Text('Salvar Desembarque',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, Color azul,
      {bool readOnly = false, VoidCallback? onTap}) {
    return TextField(
      controller: controller,
      style: TextStyle(color: azul),
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: azul),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: azul)),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: azul)),
      ),
    );
  }

  Future<void> _mostrarDialogoAdicionarEspecie(BuildContext context) async {
    final TextEditingController especieCtrl = TextEditingController();
    final TextEditingController qtdCtrl = TextEditingController();
    final TextEditingController precoCtrl = TextEditingController();
    final TextEditingController arteCtrl = TextEditingController();
    final TextEditingController pesqueiroCtrl = TextEditingController();
    String unidade = 'Kg';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar Espécie'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _buildTextField('Espécie', especieCtrl, const Color(0xFF00294D)),
              const SizedBox(height: 8),
              _buildTextField('Quantidade', qtdCtrl, const Color(0xFF00294D)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: unidade,
                items: ['Kg', 'Dúzia', 'Caixa']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => unidade = v!,
                decoration: const InputDecoration(labelText: 'Unidade de medida'),
              ),
              const SizedBox(height: 8),
              _buildTextField('Preço por unidade (R\$)', precoCtrl, const Color(0xFF00294D)),
              const SizedBox(height: 8),
              _buildTextField('Arte de pesca', arteCtrl, const Color(0xFF00294D)),
              const SizedBox(height: 8),
              _buildTextField('Pesqueiro', pesqueiroCtrl, const Color(0xFF00294D)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              _adicionarEspecie({
                'especie': especieCtrl.text,
                'quantidade': double.tryParse(qtdCtrl.text) ?? 0,
                'unidade': unidade,
                'preco_unidade': double.tryParse(precoCtrl.text) ?? 0,
                'arte_pesca': arteCtrl.text,
                'pesqueiro': pesqueiroCtrl.text,
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00294D)),
            child: const Text('Adicionar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
