import 'dart:developer';
import 'dart:io';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QRCodeScanner extends EnsembleWidget<QRCodeScannerController> {
  static const type = 'QRCodeScanner';

  const QRCodeScanner._(super.controller, {super.key});

  factory QRCodeScanner.build(dynamic controller) =>
      QRCodeScanner._(controller is QRCodeScannerController
          ? controller
          : QRCodeScannerController());

  @override
  State<StatefulWidget> createState() => QRCodeScannerState();
}

class QRCodeScannerController extends EnsembleBoxController {
  bool isFlashOn = false;
  SystemFeatures? _systemFeature;
  int? cutOutBorderRadius;
  int? cutOutBorderLength;
  int? cutOutBorderWidth;
  int? cutOutHeight;
  int? cutOutWidth;
  Color? cutOutBorderColor;
  EdgeInsets? overlayMargin;
  QRCodeScannerAction? qrCodeScannerAction;
  EnsembleAction? onReceived;
  EnsembleAction? onInitialized;
  CameraFacing mode = CameraFacing.back;
  List<String> formatsAllowed = [];
  Color? overlayColor;

  List<BarcodeFormat> get allFormatsAllowed {
    final allFormats = formatsAllowed
        .map((format) => BarcodeFormat.values.from(format))
        .whereType<BarcodeFormat>()
        .toList();
    return allFormats;
  }

  @override
  Map<String, Function> getters() {
    return {
      'formatsAllowed': () => formatsAllowed,
      'mode': () => mode.name,
      'hasBackCamera': () => _systemFeature?.hasBackCamera,
      'hasFrontCamera': () => _systemFeature?.hasFrontCamera,
      'hasFlash': () => _systemFeature?.hasFlash,
      'isFlashOn': () => isFlashOn,
    };
  }

  @override
  Map<String, Function> methods() => Map<String, Function>.from(super.methods())
    ..addAll({
      'flipCamera': () => qrCodeScannerAction?.flipCamera(),
      'toggleFlash': () => qrCodeScannerAction?.toggleFlash(),
      'pauseCamera': () => qrCodeScannerAction?.pauseCamera(),
      'resumeCamera': () => qrCodeScannerAction?.resumeCamera(),
    });

  @override
  Map<String, Function> setters() => Map<String, Function>.from(super.setters())
    ..addAll({
      'mode': (value) => mode =
          CameraFacing.values.from(Utils.optionalString(value)) ??
              CameraFacing.back,
      'formatsAllowed': (value) => formatsAllowed =
          Utils.getListOfStrings(value)?.whereType<String>().toList() ?? [],
      'overlayMargin': (value) => overlayMargin = Utils.optionalInsets(value),
      'cutOutBorderWidth': (value) =>
          cutOutBorderWidth = Utils.optionalInt(value),
      'cutOutBorderRadius': (value) =>
          cutOutBorderRadius = Utils.optionalInt(value),
      'cutOutBorderLength': (value) =>
          cutOutBorderLength = Utils.optionalInt(value),
      'cutOutHeight': (value) => cutOutHeight = Utils.optionalInt(value),
      'cutOutWidth': (value) => cutOutWidth = Utils.optionalInt(value),
      'overlayColor': (color) => overlayColor = Utils.getColor(color),
      'cutOutBorderColor': (color) => cutOutBorderColor = Utils.getColor(color),
      'onInitialized': (func) =>
          onInitialized = EnsembleAction.fromYaml(func, initiator: this),
      'onReceived': (func) =>
          onReceived = EnsembleAction.fromYaml(func, initiator: this),
    });
}

mixin QRCodeScannerAction on EnsembleWidgetState<QRCodeScanner> {
  void flipCamera();
  void toggleFlash();
  void pauseCamera();
  void resumeCamera();
}

class QRCodeScannerState extends EnsembleWidgetState<QRCodeScanner>
    with QRCodeScannerAction {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? qrController;

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      pauseCamera();
    }
    resumeCamera();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    widget.controller.qrCodeScannerAction = this;
  }

  @override
  void didUpdateWidget(covariant QRCodeScanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    widget.controller.qrCodeScannerAction = this;
  }

  @override
  Widget buildWidget(BuildContext context) {
    return EnsembleBoxWrapper(
      boxController: widget.controller,
      widget: QRView(
        key: qrKey,
        cameraFacing: widget.controller.mode,
        formatsAllowed: widget.controller.allFormatsAllowed,
        overlayMargin: widget.controller.overlayMargin ?? EdgeInsets.zero,
        overlay: QrScannerOverlayShape(
          borderColor: widget.controller.cutOutBorderColor ?? Colors.red,
          // borderColor: Colors.yellow,
          overlayColor: widget.controller.overlayColor ??
              const Color.fromRGBO(0, 0, 0, 80),
          borderRadius: Utils.getDouble(widget.controller.cutOutBorderRadius,
              fallback: 0),
          borderLength: Utils.getDouble(widget.controller.cutOutBorderLength,
              fallback: 40),
          borderWidth: Utils.getDouble(widget.controller.cutOutBorderWidth,
              fallback: 3.0),
          cutOutHeight:
              Utils.getDouble(widget.controller.cutOutHeight, fallback: 200),
          cutOutWidth:
              Utils.getDouble(widget.controller.cutOutWidth, fallback: 200),
        ),
        onQRViewCreated: _onQRViewCreated,
        onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      qrController = controller;
    });

    if (widget.controller.onInitialized != null) {
      ScreenController().executeAction(
        context,
        widget.controller.onInitialized!,
        event: EnsembleEvent(widget.controller),
      );
    }

    qrController?.scannedDataStream.listen((scanData) {
      // print('Code Data: ${scanData.code}');
      // print('Format Data: ${scanData.format}');
      // print('ToString Data: ${scanData.toString()}');
      if (widget.controller.onReceived != null) {
        final data = {
          'format': scanData.format.name,
          'data': scanData.code,
          'rawBytes': scanData.rawBytes,
        };

        ScreenController().executeAction(
          context,
          widget.controller.onReceived!,
          event: EnsembleEvent(widget.controller, data: data),
        );
      }
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    log('${DateTime.now().toIso8601String()}_onPermissionSet $p');
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('no Permission')),
      );
    }
  }

  @override
  void flipCamera() {
    qrController?.flipCamera();
  }

  // TODO:
  void getSystemFeatures() async {
    final systemFeatures = await qrController?.getSystemFeatures();
    if (systemFeatures != null) {
      widget.controller._systemFeature = systemFeatures;

      // widget.controller.mode = cameraInfo.name;
      ScopeManager? scopeManager = ScreenController().getScopeManager(context);
      if (scopeManager == null || widget.controller.id == null) return;
      // scopeManager.dataContext.addDataContextById(
      //     widget.controller.id!, SystemFeatureResponse(feature: systemFeatures));

// final contactData = scopeManager.dataContext.getContextById(id);
      // scopeManager.dispatch(ModelChangeEvent(
      //     SimpleBindingSource(widget.controller.id!),
      //     SystemFeatureResponse(feature: systemFeatures)));

      scopeManager.dispatch(
        ModelChangeEvent(
          WidgetBindingSource(widget.controller.id!, property: 'hasBackCamera'),
          systemFeatures,
          bindingScope: scopeManager,
        ),
      );
    }
  }

  @override
  void pauseCamera() {
    qrController?.pauseCamera();
  }

  @override
  void resumeCamera() {
    qrController?.resumeCamera();
  }

  @override
  void toggleFlash() async {
    await qrController?.toggleFlash();
    widget.controller.isFlashOn = !widget.controller.isFlashOn;

    // TODO:
    ScopeManager? scopeManager = ScreenController().getScopeManager(context);
    if (scopeManager == null || widget.controller.id == null) return;
    scopeManager.dispatch(
      ModelChangeEvent(
        WidgetBindingSource(widget.controller.id!, property: 'isFlashOn'),
        widget.controller.isFlashOn,
        bindingScope: scopeManager,
      ),
    );
  }
}
