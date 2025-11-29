
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; 
import 'dart:convert'; 
import 'dart:async';
import 'dart:typed_data'; 
import 'package:geolocator/geolocator.dart'; // uso de gps
import 'package:image_picker/image_picker.dart'; //uso de la camara
import 'package:google_maps_flutter/google_maps_flutter.dart'; //usar el mapa

//la url base de la fast api 
const String _apiUrl = "http://127.0.0.1:8000"; 
//lo que es la API Key no se usa aqui sino en web/index.html
//solo se usaba si es para ap movil 
void main() {
  runApp(const MyApp());
}


//modelo de datos
class Agente {
  final int id;
  final String username;
  Agente({required this.id, required this.username});
}

class Paquete {
  final String idPaquete;
  final String direccionDestino;

  Paquete({required this.idPaquete, required this.direccionDestino});

  factory Paquete.fromJson(Map<String, dynamic> json) {
    return Paquete(
      idPaquete: json['id_paquete'] as String,
      direccionDestino: json['direccion_destino'] as String,
    );
  }
}

// el widget principal y el login
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paquexpress',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF1E88E5), 
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E88E5),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _message = "Inicie sesion con sus credenciales de agente.";

  // endPoint de  LOGIN POST /login/
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _message = "Verificando las credenciales...";
    });

    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/login/'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "username": _usernameController.text,
          "password": _passwordController.text,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        final int agenteId = data['id_agente'] as int;
        final Agente agente = Agente(id: agenteId, username: _usernameController.text);
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => PaqueteListPage(agente: agente)),
        );
      } else {
        setState(() {
          _message = data['detail'] ?? "Error desconocido en el login.";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() {
        _message = "Error de conexion con la API: ${e.toString()}";
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_message), backgroundColor: Colors.red),
        );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Paquexpress"),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.delivery_dining, size: 80, color: Color(0xFF1E88E5)),
              const SizedBox(height: 20),
              const Text(
                "Inicio de Sesion",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      child: const Text('INGRESAR'),
                    ),
              const SizedBox(height: 20),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: TextStyle(color: _isLoading ? Colors.blue : Colors.red),
              ),
              const SizedBox(height: 40),
              const Text(
                "Instrucciones de Prueba:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                "Se debe de registrar el Agente y los Paquetes usando el docs de la API antes de iniciar sesion.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// 2 pantalla de lista de los oaquetes

class PaqueteListPage extends StatefulWidget {
  final Agente agente;
  const PaqueteListPage({super.key, required this.agente});

  @override
  State<PaqueteListPage> createState() => _PaqueteListPageState();
}

class _PaqueteListPageState extends State<PaqueteListPage> {
  List<Paquete> _paquetes = [];
  bool _isLoading = true;
  String _message = "Cargando las entregas...";

  @override
  void initState() {
    super.initState();
    _fetchPaquetes();
  }

  // endPoint de  GET /paquetes/{id_agente}
  Future<void> _fetchPaquetes() async {
    setState(() {
      _isLoading = true;
      _message = "Buscando los paquetes asignados...";
    });

    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/paquetes/${widget.agente.id}'),
      );

      final decodedBody = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        setState(() {
          _paquetes = (decodedBody as List)
              .map((item) => Paquete.fromJson(item))
              .toList();
          _message = "Tienes ${_paquetes.length} paquetes pendientes por entregar .";
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _paquetes = [];
          _message = decodedBody['detail'] ?? "No hay paquetes pendientes.";
        });
      } else {
        setState(() {
          _message = decodedBody['detail'] ?? "Error al cargar la lista.";
        });
      }
    } catch (e) {
      setState(() {
        _message = "Error de conexion: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Paquetes Asignados"),
        automaticallyImplyLeading: false, 
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchPaquetes,
            tooltip: 'Recargar lista',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            tooltip: 'Cerrar sesion',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Agente: ${widget.agente.username} | ${_message}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_paquetes.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 50.0),
                child: Text(_message),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _paquetes.length,
                itemBuilder: (context, index) {
                  final paquete = _paquetes[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 3,
                    child: ListTile(
                      leading: const Icon(Icons.inventory_2, color: Color(0xFF1E88E5)),
                      title: Text("Paquete: ${paquete.idPaquete}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Destino: ${paquete.direccionDestino}"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => EntregaPage(
                              agente: widget.agente,
                              paquete: paquete,
                            ),
                          ),
                        ).then((_) {
                           // Recargar la lista despuess de intentar una entrega
                          _fetchPaquetes();
                        });
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// 3 pantalla de entrega y de detalle: GPS, camara y el  mapa google maps

class EntregaPage extends StatefulWidget {
  final Agente agente;
  final Paquete paquete;
  const EntregaPage({super.key, required this.agente, required this.paquete});

  @override
  State<EntregaPage> createState() => _EntregaPageState();
}

class _EntregaPageState extends State<EntregaPage> {
  //el estado para la foto
  XFile? _pickedFile; 
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  //el estado para GPS
  Position? _currentPosition;
  String _gpsStatus = "La ubicacion no ha sido capturada. Lat y Lon seran visibles al capturar.";

  //el estado del proceso
  bool _isProcessing = false;
  String _message = "Listo para capturar evidencia.";

  //el estado para el Mapa GOOGLE MAPS 
  LatLng _mapCenter = const LatLng(20.588060, -100.388060);
  final Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    // la visualizacion de la direccion en un mapa interactivo
    _geocodeAddress(widget.paquete.direccionDestino);
  }

  // funciones de Geocodificacion de Direccion a Lat y Lon
  Future<void> _geocodeAddress(String address) async {
    // aqui usamos Nominatim servicio publico para obtener la ubicacion de la direccion
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$address&format=json&limit=1');
      final response = await http.get(url, headers: {"User-Agent": "PaquexpressApp/1.0"});

      if (response.statusCode == 200) {
        final List results = json.decode(utf8.decode(response.bodyBytes));
        if (results.isNotEmpty) {
          final lat = double.parse(results[0]['lat']);
          final lon = double.parse(results[0]['lon']);

          setState(() {
            _mapCenter = LatLng(lat, lon);
            _markers.clear();
            _markers.add(
              Marker(
                markerId: const MarkerId('destino'),
                position: _mapCenter,
                infoWindow: InfoWindow(title: 'Destino', snippet: address),
              ),
            );
          });

          //moover la camara del mapa al destino
          if (_mapController.isCompleted) {
            final controller = await _mapController.future;
            controller.animateCamera(CameraUpdate.newLatLngZoom(_mapCenter, 16));
          }
          return;
        }
      }
    } catch (e) {
      //aqui se ignora el error de geocodificacion para no romper la app si el servicio falla
    }
  }

  // funciones de la camara
  Future<void> _takePhoto() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);

    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedFile = file;
        _imageBytes = bytes;
        _message = "Foto capturada. Ahora captura el GPS.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Foto capturada correctamente.")),
      );
    } else {
      setState(() {
        _message = "No se tomo ninguna foto, vuelve a intentar .";
      });
    }
  }

  // funciones de GPS
  Future<void> _getGpsLocation() async {
    setState(() {
      _gpsStatus = "Obteniendo ubicacion...";
    });
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          _gpsStatus = "Permiso de ubicacion denegado.";
        });
        return;
      }
    }
    
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        try {
            Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 10), 
            );
            setState(() {
                _currentPosition = position;

                _gpsStatus = "GPS capturado: Lat ${position.latitude.toStringAsFixed(6)}, Lon ${position.longitude.toStringAsFixed(6)}"; 
                _message = "La foto y gps listos. Ya Puedes entregar.";
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Ubicacion GPS capturada.")),
            );
        } catch (e) {
            setState(() {
                _gpsStatus = "Error al obtener GPS: $e";
            });
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error al obtener GPS: $e")),
            );
        }
    }
  }

  // el endPoint de la  Entrega POST /entrega/
  Future<void> _deliverPackage() async {
    if (_pickedFile == null || _currentPosition == null) {
      setState(() {
        _message = "Falta capturar la foto y/o el gps.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete la evidencia.")),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _message = "Procesando entrega y subiendo la evidencia";
    });
    
    try {
      // 1 es crear la solicitud Multipart
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_apiUrl/entrega/'),
      );
      
      // 2 añadir campos de formulario  de datos del paquete y gps
      request.fields['id_paquete'] = widget.paquete.idPaquete;
      request.fields['latitud'] = _currentPosition!.latitude.toString();
      request.fields['longitud'] = _currentPosition!.longitude.toString();

      // 3 añadir el archivo 
      request.files.add(
        http.MultipartFile.fromBytes(
          'file', //nombre del campo esperado por la api
          _imageBytes!, //los bytes de la imagen
          filename: _pickedFile!.name, //el nombre del archivo original
        ),
      );

      // 4 es enviar la peticion
      var response = await request.send();
      var respStr = await response.stream.bytesToString();
      final data = json.decode(respStr);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Entrega exitosa!"), backgroundColor: Colors.green),
        );
        // se regresar a la lista para ver el paquete desaparecer
        Navigator.of(context).pop(); 
      } else {
        setState(() {
          _message = data['detail'] ?? "Error al registrar la entrega.";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_message), backgroundColor: Colors.red),
        );
      }

    } catch (e) {
      setState(() {
        _message = "Error fatal de subida: ${e.toString()}";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }


  // widgets de la pantalla 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Entrega: ${widget.paquete.idPaquete}"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            //la seccion de la direccion y mapa 
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Destino", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const Divider(),
                    Text(widget.paquete.direccionDestino, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 10),
                    Container(
                      height: 250,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300)
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                     
                        child: GoogleMap(
                          onMapCreated: (GoogleMapController controller) {
                            _mapController.complete(controller);
                          },
                          initialCameraPosition: CameraPosition(
                            target: _mapCenter,
                            zoom: 16,
                          ),
                          markers: _markers,
                          mapType: MapType.normal,
                          zoomControlsEnabled: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // la seccion de captura de evidencia , foto y gps
            const Text("Evidencia de Entrega", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(),

            // boton y review de la foto
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _takePhoto,
              icon: const Icon(Icons.camera_alt),
              label: const Text("1. CAPTURAR FOTO"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
            if (_imageBytes != null)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Center(
                  child: Image.memory(_imageBytes!, height: 150, fit: BoxFit.cover),
                ),
              ),

            const SizedBox(height: 20),

            // boton y estando del gps
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _getGpsLocation,
              icon: const Icon(Icons.location_on),
              label: const Text("2. OBTENER UBICACION GPS"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "Estado GPS: $_gpsStatus", // se ve la lat y lon
                textAlign: TextAlign.center,
                style: TextStyle(color: _currentPosition != null ? Colors.green.shade800 : Colors.red.shade800),
              ),
            ),
            
            const SizedBox(height: 30),

            //el botn de entrega 
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _deliverPackage,
              icon: _isProcessing ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Icon(Icons.check_circle_outline),
              label: Text(_isProcessing ? 'GUARDANDO...' : '3. PAQUETE ENTREGADO'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(167, 21, 21, 1), // Rojo para la acción final
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 20),
            
            //mensaje de estado
            Text(
              "Mensaje: $_message",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}