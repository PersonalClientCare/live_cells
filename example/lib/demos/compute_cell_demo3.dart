import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:live_cells/live_cells.dart';

class ComputeCellDemo3 extends StatefulWidget {
  @override
  State<ComputeCellDemo3> createState() => _ComputeCellDemo3State();
}

class _ComputeCellDemo3State extends State<ComputeCellDemo3> {
  final a = MutableCell(0);
  final b = MutableCell(0);
  
  late final sum = ComputeCell(
      compute: () => a.value + b.value, 
      arguments: [a,b]
  );
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Computational Cells 3'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Demonstration of computational cells with multiple argument cells',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('A:'),
                  const SizedBox(width: 5),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.numberWithOptions(signed: true),
                      onChanged: (value) {
                        a.value = int.tryParse(value) ?? 0;
                      },
                    ),
                  )
                ]
              ),
              Row(
                children: [
                  Text('B:'),
                  const SizedBox(width: 5),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.numberWithOptions(signed: true),
                      onChanged: (value) {
                        b.value = int.tryParse(value) ?? 0;
                      },
                    ),
                  )
                ],
              ),
              const SizedBox(height: 10),
              sum.toWidget((context, sum, _) => Text('A + B = $sum'))
            ],
          ),
        ),
      ),
    );
  }
}