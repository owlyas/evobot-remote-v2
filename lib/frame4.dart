import 'package:flutter/material.dart';
import 'controller_page.dart';

class Frame4 extends StatefulWidget {
  const Frame4({super.key});

  @override
  Frame4State createState() => Frame4State();
}

class Frame4State extends State<Frame4> {
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
                                      child: Image.network(
                                        "https://storage.googleapis.com/tagjs-prod.appspot.com/v1/QqnPwzcS2b/whv0tbyx_expires_30_days.png",
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
                        // Manual Book Card
                        Container(
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
                        // Premium Card
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Color(0xFF282931),
                          ),
                          padding: const EdgeInsets.only(left: 27, right: 27),
                          margin: const EdgeInsets.only(bottom: 69),
                          width: double.infinity,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 54),
                                child: Text(
                                  "PREMIUM",
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
                                  "https://storage.googleapis.com/tagjs-prod.appspot.com/v1/QqnPwzcS2b/ea4k7vd7_expires_30_days.png",
                                  fit: BoxFit.fill,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(Icons.star,
                                        color: Colors.amber);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
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
