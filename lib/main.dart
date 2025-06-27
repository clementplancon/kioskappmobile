import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// MODELS

class Specs {
  String marque;
  String modele;
  String os;
  String ram;
  String stockage;
  String tailleEcran;
  String resolution;
  String cpu;
  String batterie;
  String indiceReparabilite;
  String prix;
  String videoUrl;

  Specs({
    this.marque = '',
    this.modele = '',
    this.os = '',
    this.ram = '',
    this.stockage = '',
    this.tailleEcran = '',
    this.resolution = '',
    this.cpu = '',
    this.batterie = '',
    this.indiceReparabilite = '',
    this.prix = '',
    this.videoUrl = '', 
  });

  Map<String, String> toMap() => {
        'marque': marque,
        'modele': modele,
        'os': os,
        'ram': ram,
        'stockage': stockage,
        'tailleEcran': tailleEcran,
        'resolution': resolution,
        'cpu': cpu,
        'batterie': batterie,
        'indiceReparabilite': indiceReparabilite,
        'prix': prix,
        'videoUrl': videoUrl,
      };

  factory Specs.fromMap(Map<String, dynamic> map) => Specs(
        marque: map['marque'] ?? '',
        modele: map['modele'] ?? '',
        os: map['os'] ?? '',
        ram: map['ram'] ?? '',
        stockage: map['stockage'] ?? '',
        tailleEcran: map['tailleEcran'] ?? '',
        resolution: map['resolution'] ?? '',
        cpu: map['cpu'] ?? '',
        batterie: map['batterie'] ?? '',
        indiceReparabilite: map['indiceReparabilite'] ?? '',
        prix: map['prix'] ?? '',
        videoUrl: map['videoUrl'] ?? '',
      );
}

// PROVIDER

class SpecsProvider extends ChangeNotifier {
  Specs specs = Specs();
  bool isKiosk = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final map = prefs.getString('specs');
    if (map != null) {
      specs = Specs.fromMap(Map<String, dynamic>.from(
          Map<String, dynamic>.from(await Future.value(Map<String, dynamic>.from(Uri.decodeFull(map) as dynamic)))));
      notifyListeners();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('specs', specs.toMap().toString());
  }

  void updateSpecs(Specs newSpecs) {
    specs = newSpecs;
    save();
    notifyListeners();
  }

  void setKiosk(bool value) {
    isKiosk = value;
    notifyListeners();
  }
}

// --- GESTION IMAGE INDICE DE REPARABILITE ---
Future<bool> assetExists(String path) async {
  try {
    await rootBundle.load(path);
    return true;
  } catch (_) {
    return false;
  }
}

// MAIN

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => SpecsProvider(),
      child: const MyApp(),
    ),
  );
}

// APP

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fiche Téléphone',
      theme: ThemeData(
        fontFamily: 'Arial',
        scaffoldBackgroundColor: Colors.transparent,
        brightness: Brightness.light,
      ),
      debugShowCheckedModeBanner: false,
      home: const GradientBackground(child: HomeScreen()),
    );
  }
}

class GradientBackground extends StatelessWidget {
  final Widget child;
  const GradientBackground({required this.child, super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFBD82), Color(0xFFD14800)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}

// HOME

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final adminPin = "2431"; // <-- change ici pour ton code admin
  late Specs specs;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadSpecs();
  }

  Future<void> _loadSpecs() async {
    final provider = Provider.of<SpecsProvider>(context, listen: false);
    await provider.load();
    specs = provider.specs;
    // Pré-remplir
    await _autofill();
    setState(() {
      loading = false;
    });
  }

  Future<void> _autofill() async {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final data = await info.androidInfo;
      specs.marque = data.manufacturer ?? '';
      specs.modele = data.model ?? '';
      specs.os = 'Android ${data.version.release}';
      specs.cpu = data.hardware ?? '';
    } else if (Platform.isIOS) {
      final data = await info.iosInfo;
      specs.marque = 'Apple';
      specs.modele = data.utsname.machine ?? '';
      specs.os = '${data.systemName} ${data.systemVersion}';
      specs.cpu = data.utsname.machine ?? '';
    }
    // Les autres champs sont à remplir à la main
  }

  void _enterKioskMode() {
    Provider.of<SpecsProvider>(context, listen: false).setKiosk(true);
  }

  void _exitKioskMode() async {
    await showDialog(
      context: context,
      builder: (ctx) => AdminPinDialog(
        onValidated: () {
          Provider.of<SpecsProvider>(context, listen: false).setKiosk(false);
          Navigator.of(context).pop();
        },
        correctPin: adminPin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKiosk = context.watch<SpecsProvider>().isKiosk;
    final _screenPadding = MediaQuery.of(context).size.width > 600 ? 64.0 : 16.0;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: !isKiosk
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('Fiche Téléphone', style: TextStyle(color: Colors.black)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.play_circle_fill, color: Colors.black),
                  onPressed: _enterKioskMode,
                  tooltip: "Afficher mode Kiosk",
                )
              ],
            )
          : null,
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : isKiosk
                ? KioskScreen(onAdmin: _exitKioskMode)
                : SingleChildScrollView(
                    padding: EdgeInsets.all(_screenPadding),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SpecsForm(
                            specs: specs,
                            onChanged: (newSpecs) {
                              specs = newSpecs;
                            },
                          ),
                          const SizedBox(height: 32),
                          Center(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              ),
                              child: const Text('Enregistrer & Passer en Kiosk', style: TextStyle(fontSize: 18)),
                              onPressed: () {
                                if (_formKey.currentState?.validate() ?? false) {
                                  _formKey.currentState?.save();
                                  Provider.of<SpecsProvider>(context, listen: false).updateSpecs(specs);
                                  _enterKioskMode();
                                }
                              },
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}

// FORM

class SpecsForm extends StatefulWidget {
  final Specs specs;
  final Function(Specs) onChanged;
  const SpecsForm({required this.specs, required this.onChanged, super.key});
  @override
  State<SpecsForm> createState() => _SpecsFormState();
}

class _SpecsFormState extends State<SpecsForm> {
  late Specs specs;
  @override
  void initState() {
    super.initState();
    specs = widget.specs;
  }

  Widget input({
    required String label,
    required String initial,
    required Function(String) onSaved,
    String? suffix,
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        initialValue: initial,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 18, color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black),
          suffixText: suffix,
          filled: true,
          fillColor: Colors.white.withOpacity(0.8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        // plus de validator
        onChanged: (val) {
          onSaved(val);
          widget.onChanged(specs);
        },
        onSaved: (val) {
          onSaved(val ?? '');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        input(label: "Marque", initial: specs.marque, onSaved: (v) => specs.marque = v),
        input(label: "Modèle", initial: specs.modele, onSaved: (v) => specs.modele = v),
        input(label: "OS et version", initial: specs.os, onSaved: (v) => specs.os = v),
        input(label: "RAM", initial: specs.ram, onSaved: (v) => specs.ram = v, suffix: "Go"),
        input(label: "Stockage total", initial: specs.stockage, onSaved: (v) => specs.stockage = v, suffix: "Go"),
        input(label: "Taille écran", initial: specs.tailleEcran, onSaved: (v) => specs.tailleEcran = v, suffix: "\""),
        input(label: "Résolution écran", initial: specs.resolution, onSaved: (v) => specs.resolution = v, suffix: "px"),
        input(label: "CPU", initial: specs.cpu, onSaved: (v) => specs.cpu = v),
        input(label: "Batterie", initial: specs.batterie, onSaved: (v) => specs.batterie = v, suffix: "mAh"),
        input(label: "Indice de réparabilité", initial: specs.indiceReparabilite, onSaved: (v) => specs.indiceReparabilite = v),
        input(label: "Prix (€)", initial: specs.prix, onSaved: (v) => specs.prix = v, number: true, suffix: "€"),
        input(label: "Lien YouTube", initial: specs.videoUrl, onSaved: (v) => specs.videoUrl = v,),
      ],
    );
  }
}

// KIOSK
class KioskScreen extends StatefulWidget {
  final VoidCallback onAdmin;
  const KioskScreen({required this.onAdmin, super.key});

  @override
  State<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends State<KioskScreen> {
  YoutubePlayerController? _controller;
  String? lastVideoId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final specs = context.watch<SpecsProvider>().specs;
    final videoId = YoutubePlayer.convertUrlToId(specs.videoUrl);

    if (videoId != null && videoId.isNotEmpty) {
      if (_controller == null || lastVideoId != videoId) {
        _controller?.dispose();
        _controller = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: true,
            loop: true,
            controlsVisibleAtStart: false,
            hideControls: true,
          ),
        );
        lastVideoId = videoId;
        setState(() {});
      }
    } else {
      _controller?.dispose();
      _controller = null;
      lastVideoId = null;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final specs = context.watch<SpecsProvider>().specs;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final double baseFont = size.height / 60; // s’adapte à la hauteur
    final double titleFont = baseFont * 2.2;
    final double labelFont = baseFont * 0.85;
    final double valueFont = baseFont * 1.2;
    final double priceFont = baseFont * 2.7;
    final double padding = size.height / 40;
    final prixValue = empty(specs.prix);

    Future<String?> getIndiceImage() async {
      final val = specs.indiceReparabilite.replaceAll(',', '.');
      final path = 'assets/indices/$val.png';
      if (specs.indiceReparabilite.isNotEmpty && await assetExists(path)) {
        return path;
      }
      return null;
    }

    // Pour éviter le texte trop petit (sauf mini écran)
    double clamp(double val, double min, double max) {
      if (val < min) return min;
      if (val > max) return max;
      return val;
    }

    return GestureDetector(
      onLongPress: widget.onAdmin,
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 700 : 400,
            maxHeight: size.height,
          ),
          padding: EdgeInsets.all(clamp(padding, 8, 32)),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.93),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, spreadRadius: 2)],
          ),
          child: FutureBuilder<String?>(
            future: getIndiceImage(),
            builder: (context, snapshot) {
              final indiceWidget = (snapshot.data != null)
                  ? Image.asset(snapshot.data!, width: clamp(baseFont * 4, 32, 72), height: clamp(baseFont * 4, 32, 72))
                  : SizedBox(height: clamp(baseFont * 4, 32, 72));
              return Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo
                  Padding(
                    padding: EdgeInsets.only(bottom: clamp(baseFont * 0.5, 6, 20)),
                    child: Image.asset(
                      'assets/sl_logo/app_logo_sl.png',
                      height: clamp(baseFont * 2, 32, 64),
                      fit: BoxFit.contain,
                    ),
                  ),
                  // Titre
                  Text(
                    "${empty(specs.marque)} ${empty(specs.modele)}",
                    style: TextStyle(fontSize: clamp(titleFont, 18, 32), fontWeight: FontWeight.bold, color: Colors.black),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: clamp(baseFont * 0.2, 4, 10)),
                  Text(
                    "OS : ${empty(specs.os)}",
                    style: TextStyle(fontSize: clamp(valueFont, 10, 20), color: Colors.black),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: clamp(baseFont * 0.4, 6, 16)),
                  Divider(color: Colors.grey[300]),
                  SizedBox(height: clamp(baseFont * 0.2, 4, 12)),

                  // 1ère ligne : RAM | Stockage | Taille écran
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Flexible(child: InfoTile(label: "RAM", value: "${empty(specs.ram)} Go", labelFont: labelFont, valueFont: valueFont)),
                      Flexible(child: InfoTile(label: "Stockage", value: "${empty(specs.stockage)} Go", labelFont: labelFont, valueFont: valueFont)),
                      Flexible(child: InfoTile(label: "Écran", value: '${empty(specs.tailleEcran)}"', labelFont: labelFont, valueFont: valueFont)),
                    ],
                  ),
                  SizedBox(height: clamp(baseFont * 0.4, 4, 14)),
                  InfoTile(label: "Résolution", value: empty(specs.resolution), labelFont: labelFont, valueFont: valueFont),
                  SizedBox(height: clamp(baseFont * 0.35, 4, 14)),
                  InfoTile(label: "CPU", value: empty(specs.cpu), labelFont: labelFont, valueFont: valueFont),
                  SizedBox(height: clamp(baseFont * 0.35, 4, 14)),
                  InfoTile(label: "Batterie", value: "${empty(specs.batterie)} mAh", labelFont: labelFont, valueFont: valueFont),
                  SizedBox(height: clamp(baseFont * 0.3, 4, 14)),
                  indiceWidget,
                  if (_controller != null)
                    Container(
                      margin: EdgeInsets.symmetric(vertical: clamp(baseFont * 0.4, 8, 18)),
                      width: double.infinity,
                      height: isTablet ? 240 : 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: YoutubePlayer(
                          controller: _controller!,
                          showVideoProgressIndicator: false,
                        ),
                      ),
                    ),
                  const Spacer(),
                  prixValue != "--"
                      ? Text(
                          "$prixValue €",
                          style: TextStyle(
                            fontSize: clamp(priceFont, 28, isTablet ? 64 : 52),
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        )
                      : Text(
                          "--",
                          style: TextStyle(
                            fontSize: clamp(priceFont, 28, isTablet ? 64 : 52),
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

String empty(String? value) {
  return (value == null || value.trim().isEmpty) ? "--" : value;
}

class InfoTile extends StatelessWidget {
  final String label, value;
  final double? labelFont;
  final double? valueFont;
  const InfoTile({
    required this.label,
    required this.value,
    this.labelFont,
    this.valueFont,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: labelFont ?? 16,
              color: Colors.grey,
            )),
        Text(value,
            style: TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: valueFont ?? 20,
              color: Colors.black,
            )),
      ],
    );
  }
}


// Admin PIN dialog

class AdminPinDialog extends StatefulWidget {
  final VoidCallback onValidated;
  final String correctPin;
  const AdminPinDialog({required this.onValidated, required this.correctPin, super.key});
  @override
  State<AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<AdminPinDialog> {
  String inputPin = '';
  String error = '';
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: AlertDialog(
                title: const Text('Code Admin'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PinCodeTextField(
                      length: widget.correctPin.length,
                      obscureText: true,
                      animationType: AnimationType.fade,
                      pinTheme: PinTheme(
                        shape: PinCodeFieldShape.box,
                        borderRadius: BorderRadius.circular(8),
                        fieldHeight: 48,
                        fieldWidth: 40,
                        activeFillColor: Colors.white,
                        selectedFillColor: Colors.white,
                        inactiveFillColor: Colors.white,
                      ),
                      animationDuration: const Duration(milliseconds: 300),
                      enableActiveFill: true,
                      onChanged: (value) {
                        inputPin = value;
                      },
                      appContext: context,
                    ),
                    if (error.isNotEmpty)
                      Text(error, style: const TextStyle(color: Colors.red)),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      if (inputPin == widget.correctPin) {
                        widget.onValidated();
                      } else {
                        setState(() {
                          error = "Mauvais code";
                        });
                      }
                    },
                    child: const Text('Valider'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
