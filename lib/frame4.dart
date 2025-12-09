import 'package:flutter/material.dart';
import 'controller_page.dart';

class Frame4 extends StatefulWidget {
  const Frame4({super.key});

  @override
  Frame4State createState() => Frame4State();
}

class Frame4State extends State<Frame4> {
  // Fungsi Pop-up dengan Desain Custom (Frame334 Style)
  void _showManualDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      // Menggunakan warna latar gelap transparan sesuai referensi Frame334 (0xB00F1728)
      barrierColor: Color(0xB00F1728),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor:
              Colors.transparent, // Transparan agar bisa pakai Container custom
          insetPadding:
              EdgeInsets.symmetric(horizontal: 16), // Jarak kiri-kanan
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Color(0xFFFFFFFF),
              boxShadow: [
                BoxShadow(
                  color: Color(0x050A0C12),
                  blurRadius: 8,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 18),
            // Menggunakan MainAxisSize.min agar tinggi menyesuaikan konten (tidak full screen)
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. JUDUL POP UP
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    "Manual Penggunaan Aplikasi",
                    style: TextStyle(
                      color: Color(0xFF181D27),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // 2. ISI KONTEN (SCROLLABLE)
                Flexible(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.only(bottom: 23, left: 16, right: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStyledTextSection("1. Koneksi (Pairing)",
                            "Pastikan Bluetooth & GPS aktif. Masuk ke menu Controller, tekan tombol 'Scan' dan pilih robot EVOBOT."),
                        SizedBox(height: 12),
                        _buildStyledTextSection("2. Pergerakan",
                            "Gunakan D-Pad di kiri layar untuk menggerakkan robot Maju (F), Mundur (B), Kiri (L), dan Kanan (R)."),
                        SizedBox(height: 12),
                        _buildStyledTextSection("3. Kecepatan",
                            "Geser Slider di tengah layar untuk mengatur kecepatan motor (PWM) dari 0% hingga 100%."),
                        SizedBox(height: 12),
                        _buildStyledTextSection("4. Fitur Lain",
                            "Tombol X, Y, A, B dapat digunakan untuk fungsi khusus. Tombol Y di-set sebagai Toggle Switch."),
                      ],
                    ),
                  ),
                ),

                // 3. TOMBOL CLOSE (Style Frame334)
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Color(0xFFD5D6DA),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: Color(0xFFFFFFFF),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x0D0A0C12),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    width: double.infinity,
                    child: Column(
                      children: [
                        Text(
                          "Close",
                          style: TextStyle(
                            color: Color(0xFF414651),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper widget untuk text content agar rapi dan sesuai style referensi
  Widget _buildStyledTextSection(String title, String content) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: Color(0xFF535862), // Warna teks sesuai referensi
          fontSize: 14,
          height: 1.5,
          fontFamily: 'Inter', // Sesuaikan font jika ada
        ),
        children: [
          TextSpan(
            text: "$title\n",
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF181D27)),
          ),
          TextSpan(text: content),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          constraints: const BoxConstraints.expand(),
          color: Color(0xFFFFFFFF),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  color: Color(0xFFF2F3F6),
                  width: double.infinity,
                  height: double.infinity,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(left: 23, right: 23),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main EVOBOT Card
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Color(0xFFEAECF0),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            color: Color(0xFFF8F9FB),
                          ),
                          padding: const EdgeInsets.only(right: 25),
                          margin: const EdgeInsets.only(top: 32, bottom: 54),
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(
                                    top: 51, bottom: 13, left: 26),
                                child: Text(
                                  "EVOBOT",
                                  style: TextStyle(
                                    color: Color(0xFF000000),
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                margin:
                                    const EdgeInsets.only(bottom: 6, left: 24),
                                child: Text(
                                  "EVOLVING ROBOT",
                                  style: TextStyle(
                                    color: Color(0xFF000000),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                margin:
                                    const EdgeInsets.only(bottom: 14, left: 25),
                                width: double.infinity,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(
                                          bottom: 23, left: 15, right: 15),
                                      height: 234,
                                      width: double.infinity,
                                      child: Image.asset(
                                        "img/mobile-robot.png",
                                        fit: BoxFit.fill,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[300],
                                            child: Icon(Icons.image, size: 100),
                                          );
                                        },
                                      ),
                                    ),
                                    // START CONTROL BUTTON
                                    InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ControllerPage(),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Color(0xFFD5D6DA),
                                            width: 1,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          color: Color(0xFF9A0000),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0x0D0A0C12),
                                              blurRadius: 2,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        width: double.infinity,
                                        child: Center(
                                          child: Text(
                                            "START CONTROL",
                                            style: TextStyle(
                                              color: Color(0xFFFFFFFF),
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Manual Book Card (TRIGGER POP-UP DISINI)
                        InkWell(
                          onTap: () {
                            _showManualDialog(
                                context); // Panggil fungsi pop-up baru
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Color(0xFF282931),
                            ),
                            padding: const EdgeInsets.only(left: 27, right: 27),
                            margin: const EdgeInsets.only(bottom: 9),
                            width: double.infinity,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 54),
                                  child: Text(
                                    "Manual Book",
                                    style: TextStyle(
                                      color: Color(0xFFFFFFFF),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 35,
                                  height: 32,
                                  child: Image.network(
                                    "https://storage.googleapis.com/tagjs-prod.appspot.com/v1/QqnPwzcS2b/wvhtqmx6_expires_30_days.png",
                                    fit: BoxFit.fill,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(Icons.book,
                                          color: Colors.white);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
