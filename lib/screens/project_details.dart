import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../widgets/scale_island.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../services/templates.service.dart';
import '../widgets/piece_context_menu.dart';
import '../widgets/fabric_picker_sheet.dart';
import '../widgets/quantity_dialog.dart';
import '../services/api_client.dart';
import '../services/fabrics.service.dart';

// Screen to view processed gabarit, select pieces, and measure real scale between two points on the same piece.

class ProjectDetailsScreen extends StatefulWidget {
	final String imageUrl;
	final String? gabaritId;
	final bool avoidProcessOnInit;

	const ProjectDetailsScreen({
		super.key,
		required this.imageUrl,
		this.gabaritId,
		this.avoidProcessOnInit = false,
	});

	@override
	State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
	final TransformationController _transformController = TransformationController();
	TapDownDetails? _doubleTapDetails;
	String? _displayImageUrl; // prefer processed image URL
	Map<String, String>? _imageHeaders; // auth headers for protected images

	// Outlines and image size for hit-testing
	Size? _imageNaturalSize;
	final List<_PiecePolygon> _polygons = [];
	Size? _viewportSize; // size of the InteractiveViewer child (untransformed)
	String? _selectedPieceId;
	Offset? _lastTapGlobal;
	OverlayEntry? _menuEntry;
	OverlayEntry? _barrierEntry;
	final Map<String, int> _pieceQuantities = {}; // NumberOfPieces from API; default 0
	final Map<String, Map<String, dynamic>> _pieceMaterials = {}; // selected fabric per piece
	final Map<String, String?> _pieceNames = {}; // piece name from API
	final Map<String, dynamic> _pieceFabricIds = {}; // fabricId from API (can be int or String)
	// Resolved fabrics for display when coming from GET /gabarit/:id
	final List<Map<String, dynamic>> _resolvedFabrics = [];

	// Measurement state
	bool _measuring = false;
	Offset? _mStartImg; // start in image coordinates
	Offset? _mEndImg; // end in image coordinates
	String? _measurePieceId; // piece being measured (must match both points)
	double _realLengthCm = 0; // editable cm value equivalent to current pixel length
	bool _realLengthEdited = false; // true once user edits cm
	final TextEditingController _cmController = TextEditingController();
	bool _suppressCmChange = false; // guard to avoid treating programmatic updates as user edits

	// Derived scale (cm per pixel) once set
	double? _scaleCmPerPx;

	// Rebuild on pan/zoom to update scale indicator label tied to zoom
	void _onTransformChanged() {
		if (mounted) setState(() {});
	}

	final GlobalKey _childStackKey = GlobalKey();

	static const _brand = Color(0xFF4A6CF7);

			// No slider color sampling needed anymore

	@override
	void initState() {
		super.initState();
		_displayImageUrl = widget.imageUrl; // fallback until processed is fetched
		_unwrapHeaders();
		WidgetsBinding.instance.addPostFrameCallback((_) => _loadOutlines());
		_transformController.addListener(_onTransformChanged);
		_cmController.addListener(_onCmChanged);
	}

	void _onCmChanged() {
		if (_suppressCmChange) return;
		// When user edits the cm field, mark as edited and update _realLengthCm
		final raw = _cmController.text.trim().replaceAll(',', '.');
		final v = double.tryParse(raw) ?? 0.0;
		setState(() {
			_realLengthEdited = true;
			_realLengthCm = v >= 0 ? v : 0.0;
		});
	}

	Future<void> _unwrapHeaders() async {
		final headers = await ApiClient.getAuthHeaders();
		if (!mounted) return;
		setState(() => _imageHeaders = headers.isEmpty ? null : headers);
	}

	Future<void> _resolveImageSize() async {
		if (_imageNaturalSize != null) return;
		final url = _displayImageUrl ?? widget.imageUrl;
		final image = Image.network(url, headers: _imageHeaders);
		final completer = Completer<ui.Image>();
		image.image.resolve(const ImageConfiguration()).addListener(
			ImageStreamListener((ImageInfo info, bool _) {
				if (!completer.isCompleted) {
					completer.complete(info.image);
				}
			}, onError: (error, stackTrace) {
				if (!completer.isCompleted) {
					completer.completeError(error, stackTrace);
				}
			}),
		);
		try {
			final uiImg = await completer.future;
			if (!mounted) return;
			setState(() {
				_imageNaturalSize = Size(uiImg.width.toDouble(), uiImg.height.toDouble());
			});
		} catch (_) {}
	}

	Future<void> _loadOutlines() async {
		try {
			final svc = context.read<TemplatesService>();
			final id = widget.gabaritId;
			if (id == null || id.isEmpty) return;

			// Use cached processed data only. Do not call process or GET here.
			final data = svc.getProcessedInfo(id);
			if (data == null) {
				await _resolveImageSize();
				return;
			}

			final processedAbs = data['absoluteProcessedImageUrl'] as String?;
			if (processedAbs != null && processedAbs.isNotEmpty) {
				setState(() {
					_displayImageUrl = processedAbs;
					_imageNaturalSize = null;
				});
			}

			// Also pick up scale from cached processed data
			try {
				double? sc;
				final g = data['gabarit'];
				if (g is Map) {
					final s = g['scale'];
					if (s is num) sc = s.toDouble();
				}
				if (sc == null) {
					final s = data['scale'];
					if (s is num) sc = s.toDouble();
				}
				if (sc != null && mounted) {
					setState(() => _scaleCmPerPx = sc);
				}
			} catch (_) {}

			final pieces = data['pieces'] as List?;
			if (pieces != null) {
				final polys = <_PiecePolygon>[];
				final names = <String, String?>{};
				final quantities = <String, int>{};
				final fabricIds = <String, dynamic>{};
				for (final raw in pieces) {
					if (raw is! Map) continue;
					final pid = raw['id']?.toString();
					final outline = raw['outline'];
					if (pid == null || outline is! Map) continue;
					names[pid] = raw['name']?.toString();
					final q = raw['NumberOfPieces'];
					if (q is num) quantities[pid] = q.toInt().clamp(0, 1000000);
					final fid = raw['fabricId'];
					if (fid != null) {
						// keep original type (int or String)
						fabricIds[pid] = fid;
					}
					final pts = outline['points'] as List?;
					if (pts == null) continue;
					final offsets = <Offset>[];
					for (final p in pts) {
						if (p is Map) {
							final dx = (p['x'] as num?)?.toDouble();
							final dy = (p['y'] as num?)?.toDouble();
							if (dx != null && dy != null) offsets.add(Offset(dx, dy));
						}
					}
					if (offsets.isNotEmpty) polys.add(_PiecePolygon(id: pid, points: offsets));
				}
				if (mounted) {
					setState(() {
						_polygons
							..clear()
							..addAll(polys);
						_pieceNames
							..clear()
							..addAll(names);
						_pieceFabricIds
							..clear()
							..addAll(fabricIds);
						_pieceQuantities.addAll(quantities);
					});
					// Resolve fabric details for display
					await _resolveFabricsForPieces();
				}
			}

			final dims = data['imageDimensions'];
			if (dims is Map) {
				final w = (dims['width'] as num?)?.toDouble();
				final h = (dims['height'] as num?)?.toDouble();
				if (w != null && h != null && w > 0 && h > 0) {
					setState(() => _imageNaturalSize = Size(w, h));
					return;
				}
			}
			await _resolveImageSize();
		} catch (_) {}
	}

	Future<void> _resolveFabricsForPieces() async {
		final fabSvc = context.read<FabricsService>();
		final List<Map<String, dynamic>> unique = [];
		final Set<String> seen = {};
		for (final entry in _pieceFabricIds.entries) {
			final pid = entry.key;
			final fid = entry.value;
			if (fid == null) continue;
			final fidStr = fid.toString();
	    Map<String, dynamic>? fabric;
	    // Try caches
	    final cached = (fabSvc.fabrics + fabSvc.featuredFabrics + fabSvc.homeFullFabrics)
		    .cast<Map<String, dynamic>>()
		    .firstWhere((m) => (m['id']?.toString() ?? '') == fidStr, orElse: () => {});
	    fabric = cached.isEmpty ? null : cached;
			// Fallback to GET
			if (fabric == null) {
				final ok = await fabSvc.fetchFabricById(fidStr);
				if (ok && fabSvc.currentFabric != null) {
					fabric = Map<String, dynamic>.from(fabSvc.currentFabric!);
				}
			}
			if (fabric != null) {
				setState(() {
					_pieceMaterials[pid] = fabric!;
					final idKey = fabric['id']?.toString() ?? fidStr;
					if (!seen.contains(idKey)) {
						unique.add(fabric);
						seen.add(idKey);
					}
				});
			}
		}
		if (mounted) {
			setState(() {
				_resolvedFabrics
					..clear()
					..addAll(unique);
			});
		}
	}

	@override
	void dispose() {
		_removeMenu();
		_transformController.removeListener(_onTransformChanged);
		_transformController.dispose();
		_cmController.dispose();
		super.dispose();
	}

	void _handleDoubleTapDown(TapDownDetails details) {
		_doubleTapDetails = details;
	}

	void _handleDoubleTap() {
		final position = _doubleTapDetails?.localPosition;
		final currentMatrix = _transformController.value;
		final currentScale = currentMatrix.getMaxScaleOnAxis();
		const double minScale = 1.0;
		const double maxScale = 3.0;

		if (currentScale > minScale + 0.01) {
			// Reset to identity
			_transformController.value = Matrix4.identity();
		} else if (position != null) {
			// Zoom in focusing on the double-tap position
			final zoom = 2.0;
			final x = -position.dx * (zoom - 1);
			final y = -position.dy * (zoom - 1);
			_transformController.value = Matrix4.identity()
				..translate(x, y)
				..scale(zoom.clamp(minScale, maxScale));
		}
	}

	void _handleTapUp(TapUpDetails details) {
		// child-local position (InteractiveViewer child space)
		final childLocal = details.localPosition;
		_lastTapGlobal = details.globalPosition;

		if (_measuring) {
			_measureTap(childLocal);
		} else {
			_hitTestTap(childLocal);
		}
	}

	void _measureTap(Offset localTap) {
		if (_viewportSize == null || _imageNaturalSize == null) return;
		final rect = _containRect(_viewportSize!, _imageNaturalSize!);
		if (!rect.contains(localTap)) return;
		final scale = rect.width / _imageNaturalSize!.width;
		final imgPoint = Offset(
			(localTap.dx - rect.left) / scale,
			(localTap.dy - rect.top) / scale,
		);
		// ensure tap is inside a piece; set/verify same piece
		String? hitId;
		for (final poly in _polygons) {
			if (_pointInPolygon(imgPoint, poly.points)) {
				hitId = poly.id;
				break;
			}
		}
		if (hitId == null) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Touchez une pièce pour mesurer')));
			return;
		}
		if (_measurePieceId != null && _measurePieceId != hitId) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mesure: choisissez 2 points dans la même pièce')));
			return;
		}
		setState(() {
			_selectedPieceId = hitId;
			_measurePieceId = hitId;
		});
				const perimeterSnapThreshold = 4.0; // tighter perimeter snap (image pixels)
				if (_mStartImg == null) {
					var startOn = _clampToPieceInterior(hitId, imgPoint);
					startOn = _maybeSnapPerimeter(hitId, startOn, perimeterSnapThreshold);
			setState(() {
				_mStartImg = startOn;
				_mEndImg = null;
				// reset cm editing on new measurement start
				_realLengthEdited = false;
				_realLengthCm = 0;
				_suppressCmChange = true;
				_cmController.clear();
				_suppressCmChange = false;
			});
			return;
		}
				var endOn = _clampToPieceInterior(hitId, imgPoint);
					endOn = _snapMovingPoint(
						fixed: _mStartImg!,
						moving: endOn,
						pieceId: hitId,
						degThreshold: 4.0, // tighter H/V snap (degrees)
						perimeterSnapThreshold: perimeterSnapThreshold,
					);
			setState(() {
					_mEndImg = endOn;
					// default cm follows px until user edits
					final pxLen = _currentPixelLength();
					if (!_realLengthEdited) {
						_realLengthCm = (pxLen ?? 0);
						_suppressCmChange = true;
						_cmController.text = (pxLen ?? 0).toStringAsFixed(1);
						_suppressCmChange = false;
					}
		});
	}

	double? _currentPixelLength() {
		if (_mStartImg == null || _mEndImg == null) return null;
		final d = _mEndImg! - _mStartImg!;
		return d.distance;
	}

		// Scale computation not used in this simplified UX

	void _hitTestTap(Offset localTap) {
		if (_viewportSize == null || _imageNaturalSize == null || _polygons.isEmpty) return;
		final rect = _containRect(_viewportSize!, _imageNaturalSize!);
		if (!rect.contains(localTap)) return;
		final scale = rect.width / _imageNaturalSize!.width; // uniform for contain
		final imgPoint = Offset(
			(localTap.dx - rect.left) / scale,
			(localTap.dy - rect.top) / scale,
		);

		for (final poly in _polygons) {
			if (_pointInPolygon(imgPoint, poly.points)) {
				setState(() => _selectedPieceId = poly.id);
				_showPieceMenu();
				return;
			}
		}
		setState(() => _selectedPieceId = null);
	}

	void _showPieceMenu() {
		_removeMenu();
		if (_lastTapGlobal == null) return;
		final overlay = Overlay.of(context);
		final overlayBox = overlay.context.findRenderObject() as RenderBox;
		final local = overlayBox.globalToLocal(_lastTapGlobal!);
		const menuWidth = 220.0;
		const menuHeight = 140.0;
		final screenSize = overlayBox.size;
		final left = (local.dx - menuWidth / 2).clamp(8.0, screenSize.width - menuWidth - 8.0);
		final top = (local.dy - 8).clamp(8.0, screenSize.height - menuHeight - 8.0);

		_barrierEntry = OverlayEntry(
			builder: (_) => Positioned.fill(
				child: GestureDetector(
					behavior: HitTestBehavior.opaque,
					onTap: _removeMenu,
					child: const SizedBox.shrink(),
				),
			),
		);

		final id = _selectedPieceId;
		final selectedFabric = id == null ? null : _pieceMaterials[id];
		final qty = id == null ? 0 : (_pieceQuantities[id] ?? 0);
		final pieceTitle = id == null ? null : (_pieceNames[id] ?? 'Pièce $id');
		_menuEntry = OverlayEntry(
			builder: (ctx) => Positioned(
				left: left,
				top: top,
				child: Material(
					color: Colors.transparent,
					child: PieceContextMenu(
						pieceTitle: pieceTitle,
						selectedFabric: selectedFabric,
						quantity: qty,
						onPickFabric: () async {
							final id = _selectedPieceId;
							_removeMenu();
							if (id == null) return;
							final picked = await showFabricPickerSheet(context, resetList: true);
							if (!mounted) return;
														if (picked != null) {
															setState(() {
																_pieceMaterials[id] = picked;
																final dynamic fid = picked['id'];
																if (fid != null) {
																	_pieceFabricIds[id] = fid; // accept int or String
																}
															});
								ScaffoldMessenger.of(context).showSnackBar(
									SnackBar(content: Text('Matière appliquée à ${_pieceNames[id] ?? 'pièce $id'}')),
								);
							}
						},
						onChangeQuantity: () async {
							final id = _selectedPieceId;
							_removeMenu();
							if (id == null) return;
							final current = _pieceQuantities[id] ?? 0;
							final newQty = await showQuantityDialog(context, initial: current, allowZero: true);
							if (!mounted) return;
							if (newQty != null && newQty >= 0) {
								setState(() => _pieceQuantities[id] = newQty);
								ScaffoldMessenger.of(context).showSnackBar(
									SnackBar(content: Text('Quantité mise à jour: x$newQty pour ${_pieceNames[id] ?? 'pièce $id'}')),
								);
							}
						},
					),
				),
			),
		);
		overlay.insert(_barrierEntry!);
		overlay.insert(_menuEntry!);
	}

	void _removeMenu() {
		_menuEntry?.remove();
		_menuEntry = null;
		_barrierEntry?.remove();
		_barrierEntry = null;
	}

	Rect _containRect(Size viewport, Size image) {
		final vpW = viewport.width;
		final vpH = viewport.height;
		final imgW = image.width;
		final imgH = image.height;
		if (imgW <= 0 || imgH <= 0 || vpW <= 0 || vpH <= 0) return Rect.zero;
		final scale = (vpW / imgW).clamp(0.0, double.infinity);
		final scaledH = imgH * scale;
		double width, height, dx = 0, dy = 0;
		if (scaledH <= vpH) {
			width = vpW;
			height = scaledH;
			dy = (vpH - height) / 2;
		} else {
			final scale2 = vpH / imgH;
			width = imgW * scale2;
			height = vpH;
			dx = (vpW - width) / 2;
		}
		return Rect.fromLTWH(dx, dy, width, height);
	}

	bool _pointInPolygon(Offset p, List<Offset> poly) {
		// Ray casting algorithm
		int count = 0;
		for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
			final yi = poly[i].dy, yj = poly[j].dy;
			final xi = poly[i].dx, xj = poly[j].dx;
			final intersect = ((yi > p.dy) != (yj > p.dy)) &&
					(p.dx < (xj - xi) * (p.dy - yi) / ((yj - yi) == 0 ? 1e-9 : (yj - yi)) + xi);
			if (intersect) count++;
		}
		return (count % 2) == 1;
	}

	// Project a point to the nearest point on the border of a piece polygon.
	Offset _projectToPieceBorder(String pieceId, Offset imgPoint) {
		final poly = _polygons.firstWhere((p) => p.id == pieceId, orElse: () => _PiecePolygon(id: pieceId, points: const []));
		if (poly.points.isEmpty) return imgPoint;
		double bestDist2 = double.infinity;
		Offset bestPt = imgPoint;
		final pts = poly.points;
		for (int i = 0; i < pts.length; i++) {
			final a = pts[i];
			final b = pts[(i + 1) % pts.length];
			final ab = b - a;
			final ap = imgPoint - a;
			final abLen2 = ab.dx * ab.dx + ab.dy * ab.dy;
			if (abLen2 == 0) continue;
			double t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLen2;
			t = t.clamp(0.0, 1.0);
			final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
			final diff = proj - imgPoint;
			final d2 = diff.dx * diff.dx + diff.dy * diff.dy;
			if (d2 < bestDist2) {
				bestDist2 = d2;
				bestPt = proj;
			}
		}
		return bestPt;
	}

		// Keep the point inside the piece polygon; if outside, clamp to nearest border.
		Offset _clampToPieceInterior(String pieceId, Offset imgPoint) {
			final poly = _polygons.firstWhere((p) => p.id == pieceId, orElse: () => _PiecePolygon(id: pieceId, points: const []));
			if (poly.points.isEmpty) return imgPoint;
			if (_pointInPolygon(imgPoint, poly.points)) return imgPoint;
			return _projectToPieceBorder(pieceId, imgPoint);
		}

		// Snap moving point relative to a fixed point: optional H/V snapping and perimeter snap, then clamp inside polygon.
		Offset _snapMovingPoint({
			required Offset fixed,
			required Offset moving,
			required String pieceId,
			double degThreshold = 8.0,
			double perimeterSnapThreshold = 8.0,
		}) {
			// H/V snap
			final v = moving - fixed;
			final angle = math.atan2(v.dy, v.dx);
			final angleDeg = angle * 180 / math.pi;
			final absDeg = angleDeg.abs();
			final isHoriz = (absDeg < degThreshold) || (absDeg > 180 - degThreshold);
			final isVert = ((absDeg - 90).abs() < degThreshold);
			var snapped = moving;
			if (isHoriz) snapped = Offset(moving.dx, fixed.dy);
			if (isVert) snapped = Offset(fixed.dx, moving.dy);

			// Perimeter snap if near
			snapped = _maybeSnapPerimeter(pieceId, snapped, perimeterSnapThreshold);

			// Clamp inside polygon
			snapped = _clampToPieceInterior(pieceId, snapped);
			return snapped;
		}

	Offset _imageToViewport(Offset img) {
		if (_viewportSize == null || _imageNaturalSize == null) return img;
		final rect = _containRect(_viewportSize!, _imageNaturalSize!);
		final scale = rect.width / _imageNaturalSize!.width;
		return Offset(rect.left + img.dx * scale, rect.top + img.dy * scale);
	}

	Offset _viewportToImage(Offset vp) {
		if (_viewportSize == null || _imageNaturalSize == null) return vp;
		final rect = _containRect(_viewportSize!, _imageNaturalSize!);
		final scale = rect.width / _imageNaturalSize!.width;
		return Offset((vp.dx - rect.left) / scale, (vp.dy - rect.top) / scale);
	}

			void _onDragHandleDelta(bool isStart, Offset deltaInChild) {
		if (_mStartImg == null || _mEndImg == null || _measurePieceId == null) return;
		// Convert current handle viewport position + delta back to image space
		final currentVp = _imageToViewport(isStart ? _mStartImg! : _mEndImg!);
		final nextVp = currentVp + deltaInChild;
		var img = _viewportToImage(nextVp);
				final fixed = isStart ? _mEndImg! : _mStartImg!;
					final snapped = _snapMovingPoint(
					fixed: fixed,
					moving: img,
					pieceId: _measurePieceId!,
						degThreshold: 4.0,
						perimeterSnapThreshold: 4.0,
				);
				setState(() {
					if (isStart) {
						_mStartImg = snapped;
					} else {
						_mEndImg = snapped;
					}
					// keep cm default synced unless user edited
					if (!_realLengthEdited) {
						final pxLen = _currentPixelLength();
						_realLengthCm = (pxLen ?? 0);
						_suppressCmChange = true;
						_cmController.text = (pxLen ?? 0).toStringAsFixed(1);
						_suppressCmChange = false;
					}
				});
	}

			// Snap to the perimeter if within a threshold (image pixels); else return original point.
			Offset _maybeSnapPerimeter(String pieceId, Offset p, double threshold) {
				final proj = _projectToPieceBorder(pieceId, p);
				final d = (proj - p).distance;
				if (d <= threshold) return proj;
				return p;
			}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Segmentation du gabarit'),
			),
			body: LayoutBuilder(
				builder: (context, constraints) {
					_viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
					return Stack(
						children: [
							// Main content (transformed together)
							Positioned.fill(
								child: GestureDetector(
									onDoubleTapDown: _handleDoubleTapDown,
									onDoubleTap: _handleDoubleTap,
									onTapUp: _handleTapUp,
									child: InteractiveViewer(
										transformationController: _transformController,
										minScale: 0.8,
										maxScale: 5.0,
										child: Stack(
											key: _childStackKey,
											children: [
												// Base image
												Positioned.fill(
													child: _displayImageUrl == null
															? const SizedBox.shrink()
															: Image.network(
																	_displayImageUrl!,
																	headers: _imageHeaders,
																	fit: BoxFit.contain,
																),
												),

												// Selected piece highlight
												if (_selectedPieceId != null && _imageNaturalSize != null && _viewportSize != null)
													Positioned.fill(
														child: IgnorePointer(
															child: CustomPaint(
																painter: _SelectionPainter(
																	polygons: _polygons,
																	selectedId: _selectedPieceId!,
																	viewport: _viewportSize!,
																	imageSize: _imageNaturalSize!,
																),
															),
														),
													),

																														// Single start point marker (when only first point set)
																														if (_measuring && _mStartImg != null && _mEndImg == null && _viewportSize != null && _imageNaturalSize != null)
																																Positioned.fill(
																																	child: IgnorePointer(
																																		child: CustomPaint(
																																			painter: _SinglePointPainter(
																																				point: _imageToViewport(_mStartImg!),
																																				color: _brand,
																																				radius: 5,
																																			),
																																		),
																																	),
																																),

																		// Measurement line + draggable handles (inside transformed child)
												if (_measuring && _mStartImg != null && _mEndImg != null && _viewportSize != null && _imageNaturalSize != null) ...[
													Positioned.fill(
														child: IgnorePointer(
															child: CustomPaint(
																painter: _MeasurementPainter(
																	start: _imageToViewport(_mStartImg!),
																	end: _imageToViewport(_mEndImg!),
																	color: _brand,
																),
															),
														),
													),
													// Start handle
													Positioned(
														left: _imageToViewport(_mStartImg!).dx - 12,
														top: _imageToViewport(_mStartImg!).dy - 12,
														child: _DragHandle(
															color: _brand,
															onPanDelta: (delta) => _onDragHandleDelta(true, delta),
														),
													),
													// End handle
													Positioned(
														left: _imageToViewport(_mEndImg!).dx - 12,
														top: _imageToViewport(_mEndImg!).dy - 12,
														child: _DragHandle(
															color: _brand,
															onPanDelta: (delta) => _onDragHandleDelta(false, delta),
														),
																															),
																													], // end spread measurement widgets
																												], // end Stack children
																											),
									),
								),
							),

							// If we resolved fabrics via GET/:id, display a small list overlay
							if (_resolvedFabrics.isNotEmpty)
								Positioned(
									left: 12,
									right: 12,
									bottom: 72,
									child: SafeArea(
										top: false,
										child: Container(
											padding: const EdgeInsets.all(12),
											decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)]),
											child: Column(
												mainAxisSize: MainAxisSize.min,
												crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													const Text('Tissus associés', style: TextStyle(fontWeight: FontWeight.w700)),
													const SizedBox(height: 8),
													..._resolvedFabrics.take(4).map((f) {
														final title = (f['title'] ?? f['name'] ?? 'Tissu').toString();
														final type = (f['type'] ?? '').toString();
														return Padding(
															padding: const EdgeInsets.symmetric(vertical: 2),
															child: Text('• $title${type.isNotEmpty ? ' — $type' : ''}'),
														);
													}).toList(),
												],
											),
										),
									),
																			),
							// End fabrics overlay

																						// Measurement controls: Set scale button (hidden while measuring)
																						if (!_measuring)
																							Positioned(
																								left: 12,
																								top: 12,
																								child: SafeArea(
																									top: true,
																									child: ElevatedButton.icon(
																										style: ElevatedButton.styleFrom(
																											backgroundColor: Colors.white,
																											foregroundColor: Colors.black87,
																											side: const BorderSide(color: _brand),
																										),
																										icon: const Icon(Icons.straighten),
																										label: const Text('Set scale'),
																										onPressed: () {
																											setState(() {
																												_measuring = true;
																												// initialize overlay with 0 px = 0 cm; lock editing until two points picked
																												_mStartImg = null;
																												_mEndImg = null;
																												_measurePieceId = null;
																												_realLengthEdited = false;
																												_realLengthCm = 0;
																											_suppressCmChange = true;
																											_cmController.text = '0';
																											_suppressCmChange = false;
																											});
																										},
																									),
																								),
																							),

																																	if (_measuring)
																																		Positioned(
																																			left: 12,
																																			right: 12,
																																			top: 12,
																																			child: ScaleIsland(
																																				pixelLength: (_mStartImg != null && _mEndImg != null) ? (_currentPixelLength() ?? 0) : 0,
																																				cmController: _cmController,
																																				enableEditing: _mStartImg != null && _mEndImg != null,
																																				showActions: _mStartImg != null && _mEndImg != null,
																																				accentColor: _brand,
																																				onCancel: () {
																																					setState(() {
																																						_measuring = false;
																																						_mStartImg = null;
																																						_mEndImg = null;
																																						_measurePieceId = null;
																																						_realLengthEdited = false;
																																						_realLengthCm = 0;
																																						_suppressCmChange = true;
																																						_cmController.clear();
																																						_suppressCmChange = false;
																																					});
																																				},
																										onConfirm: () {
																																					final pxLen = _currentPixelLength();
																																					if ((_mStartImg != null && _mEndImg != null) && _realLengthCm > 0 && (pxLen ?? 0) > 0) {
																																						setState(() {
																											final s = _realLengthCm / (pxLen!);
																											_scaleCmPerPx = double.parse(s.toStringAsFixed(6));
																																							_measuring = false;
																																							_mStartImg = null;
																																							_mEndImg = null;
																																							_measurePieceId = null;
																																							_realLengthEdited = false;
																																							_realLengthCm = 0;
																																							_suppressCmChange = true;
																																							_cmController.clear();
																																							_suppressCmChange = false;
																																						});
																																						ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scale set')));
																																					}
																																				},
																																			),
																																		),

											    // Scale indicator (always visible; scale is fetched from GET/process or set via measuring)
											    if (_viewportSize != null && _imageNaturalSize != null)
															Positioned(
																left: 12,
																bottom: 72,
							    child: _ScaleIndicator(
						    cmPerPx: _currentCmPerPxForIndicator(),
																	color: _brand,
																	containScale: _containRect(_viewportSize!, _imageNaturalSize!).width / _imageNaturalSize!.width,
																	zoom: _transformController.value.getMaxScaleOnAxis(),
																),
															),

														// Bottom action: persist quantities and scale (gated by readiness)
														Positioned(
								left: 0,
								right: 0,
								bottom: 12,
								child: SafeArea(
									top: false,
									child: Center(
																				child: Builder(builder: (context) {
																					final bool hasScale = _scaleCmPerPx != null;
																					final bool allHaveFabric = _polygons.isEmpty || _polygons.every((p) => (_pieceMaterials[p.id] != null) || (_pieceFabricIds[p.id] != null));
																					final bool ready = hasScale && allHaveFabric;
																					final Color bg = ready ? Colors.white : Colors.grey.shade300;
																					final Color fg = ready ? Colors.black87 : Colors.grey.shade600;
																					final Color side = ready ? _brand : Colors.grey.shade400;
																					return ElevatedButton(
																						onPressed: () async {
																							if (!ready) {
																								final reasons = <String>[];
																								if (!hasScale) reasons.add('Set the scale');
																								if (!allHaveFabric) reasons.add('Assign a fabric to every piece');
																								final msg = 'Cannot validate: ${reasons.join(' and ')}.';
																								ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
																								return;
																							}
																							final id = widget.gabaritId;
																							if (id == null || id.isEmpty) return;
																																			final svc = context.read<TemplatesService>();
																																			  final scale = _scaleCmPerPx;
																																																															// Prepare piece payloads for patch (fabricId, NumberOfPieces, and name)
																																																															final piecePayloads = _polygons.map((p) {
																																																																final name = _pieceNames[p.id];
																																																																final qty = _pieceQuantities[p.id] ?? 0;
																																																																final fid = _pieceFabricIds[p.id];
																																																																return {
																																																																	'id': p.id,
																																																																	'NumberOfPieces': qty,
																																																																	if (fid != null) 'fabricId': fid,
																																																																	if (name != null && name.isNotEmpty) 'name': name,
																																																																};
																																																															}).toList();
																																			bool ok = true;
																																																																														 if (scale != null) {
																																																																																// Only apply scale to gabarit, not to pieces
																																																																																final s6 = double.parse(scale.toStringAsFixed(6));
																																																																																ok = await svc.updateGabaritScalePatch(id, s6);
																																																																															}
																																															// Always patch piece quantities/fabrics (without scale)
																																															for (final m in piecePayloads) {
																																																final pid = m['id'] as String;
																																																final fields = <String, dynamic>{};
																																																if (m['NumberOfPieces'] != null) fields['NumberOfPieces'] = m['NumberOfPieces'];
																																																if (m['fabricId'] != null) fields['fabricId'] = m['fabricId'];
																																																if (m['name'] != null) fields['name'] = m['name'];
																																																																															 if (fields.isEmpty) continue;
																																																final r = await svc.patchPiece(pid, fields);
																																																ok = ok && r;
																																															}
																																			if (!mounted) return;
																																			if (ok) {
																																																										// Update local cache to reflect saved values
																																																										try {
																																																											final data = svc.getProcessedInfo(id);
																																																											if (data != null) {
																																																												final updated = Map<String, dynamic>.from(data);
																																																												if (scale != null) {
																																																													final g = Map<String, dynamic>.from((updated['gabarit'] as Map?) ?? {});
																																																													g['scale'] = scale;
																																																													updated['gabarit'] = g;
																																																													updated['scale'] = scale;
																																																												}
																																																												final list = (updated['pieces'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
																																																												for (final p in list) {
																																																													final pid = p['id']?.toString();
																																																													if (pid == null) continue;
																																																													p['NumberOfPieces'] = _pieceQuantities[pid] ?? 0;
																																																													if (_pieceFabricIds[pid] != null) p['fabricId'] = _pieceFabricIds[pid];
																																																													final n = _pieceNames[pid];
																																																													if (n != null && n.isNotEmpty) p['name'] = n;
																																																												}
																																																												updated['pieces'] = list;
																																																												svc.cacheProcessedInfo(id, updated);
																																																											}
																																																										} catch (_) {}
																																																										ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modifications enregistrées')));
																														// Return to New Project screen
																														Navigator.pop(context);
																													} else {
																								ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Échec de l\'enregistrement')));
																							}
																						},
																						style: ElevatedButton.styleFrom(
																							backgroundColor: bg,
																							foregroundColor: fg,
																							side: BorderSide(color: side),
																						),
																						child: const Text('Valider', style: TextStyle(fontWeight: FontWeight.w600)),
																					);
																				}),
									),
								),
							),
						],
					);
				},
			),
		);
	}
}

	extension _ScalePreview on _ProjectDetailsScreenState {
		double _currentCmPerPxForIndicator() {
			if (_measuring && _mStartImg != null && _mEndImg != null) {
				final px = _currentPixelLength();
				final cm = _realLengthCm;
				if ((px ?? 0) > 0 && cm > 0) {
		final s = cm / (px!);
		return double.parse(s.toStringAsFixed(6));
				}
			}
			return _scaleCmPerPx ?? 1.0;
		}
	}

class _PiecePolygon {
	final String id;
	final List<Offset> points;
	const _PiecePolygon({required this.id, required this.points});
}

class _SelectionPainter extends CustomPainter {
	final List<_PiecePolygon> polygons;
	final String selectedId;
	final Size viewport;
	final Size imageSize;
	const _SelectionPainter({
		required this.polygons,
		required this.selectedId,
		required this.viewport,
		required this.imageSize,
	});

	@override
	void paint(Canvas canvas, Size size) {
		final rect = _containRect(viewport, imageSize);
		canvas.save();
		canvas.clipRect(rect);
		final scale = rect.width / imageSize.width; // contain uniform scale
		final dx = rect.left;
		final dy = rect.top;
		final path = Path();
		final fillPaint = Paint()
			..style = PaintingStyle.fill
			..color = Colors.blue.withOpacity(0.35);
		final strokePaint = Paint()
			..style = PaintingStyle.stroke
			..strokeWidth = 2
			..color = Colors.blueAccent;

		for (final poly in polygons) {
			if (poly.id != selectedId) continue;
			path.reset();
			for (int i = 0; i < poly.points.length; i++) {
				final p = poly.points[i];
				final x = dx + p.dx * scale;
				final y = dy + p.dy * scale;
				if (i == 0) {
					path.moveTo(x, y);
				} else {
					path.lineTo(x, y);
				}
			}
			path.close();
			canvas.drawPath(path, fillPaint);
			canvas.drawPath(path, strokePaint);
		}

		canvas.restore();
	}

	Rect _containRect(Size viewport, Size image) {
		final vpW = viewport.width;
		final vpH = viewport.height;
		final imgW = image.width;
		final imgH = image.height;
		if (imgW <= 0 || imgH <= 0 || vpW <= 0 || vpH <= 0) return Rect.zero;
		final scale = (vpW / imgW).clamp(0.0, double.infinity);
		final scaledH = imgH * scale;
		double width, height, dx = 0, dy = 0;
		if (scaledH <= vpH) {
			width = vpW;
			height = scaledH;
			dy = (vpH - height) / 2;
		} else {
			final scale2 = vpH / imgH;
			width = imgW * scale2;
			height = vpH;
			dx = (vpW - width) / 2;
		}
		return Rect.fromLTWH(dx, dy, width, height);
	}

	@override
	bool shouldRepaint(covariant _SelectionPainter oldDelegate) {
		return oldDelegate.selectedId != selectedId ||
				oldDelegate.polygons != polygons ||
				oldDelegate.viewport != viewport ||
				oldDelegate.imageSize != imageSize;
	}
}

class _MeasurementPainter extends CustomPainter {
	final Offset start;
	final Offset end;
	final Color color;
	const _MeasurementPainter({required this.start, required this.end, required this.color});

	@override
	void paint(Canvas canvas, Size size) {
		final paint = Paint()
			..color = color
			..strokeWidth = 2
			..style = PaintingStyle.stroke;
		canvas.drawLine(start, end, paint);
		final fill = Paint()..color = color;
		canvas.drawCircle(start, 4, fill);
		canvas.drawCircle(end, 4, fill);
	}

	@override
	bool shouldRepaint(covariant _MeasurementPainter oldDelegate) {
		return oldDelegate.start != start || oldDelegate.end != end || oldDelegate.color != color;
	}
}

class _SinglePointPainter extends CustomPainter {
	final Offset point;
	final Color color;
	final double radius;
	const _SinglePointPainter({required this.point, required this.color, this.radius = 5});

	@override
	void paint(Canvas canvas, Size size) {
		final fill = Paint()..color = color;
		final stroke = Paint()
			..color = color
			..style = PaintingStyle.stroke
			..strokeWidth = 2;
		canvas.drawCircle(point, radius, fill);
		canvas.drawCircle(point, radius + 3, stroke);
	}

	@override
	bool shouldRepaint(covariant _SinglePointPainter oldDelegate) {
		return oldDelegate.point != point || oldDelegate.color != color || oldDelegate.radius != radius;
	}
}

class _DragHandle extends StatelessWidget {
	final Color color;
	final ValueChanged<Offset> onPanDelta; // delta in the same local (child) space
	const _DragHandle({required this.color, required this.onPanDelta});

	@override
	Widget build(BuildContext context) {
		return GestureDetector(
			onPanUpdate: (d) => onPanDelta(d.delta),
			child: Container(
				width: 24,
				height: 24,
				decoration: BoxDecoration(
					color: color,
					shape: BoxShape.circle,
					boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
				),
			),
		);
	}
}

// Small half-square scale indicator with perpendicular arrows and a label
class _ScaleIndicator extends StatelessWidget {
	final double cmPerPx;
	final Color color;
	// containScale: viewportImageWidth / imageNaturalWidth for BoxFit.contain
	// zoom: InteractiveViewer scale factor
	final double containScale;
	final double zoom;
	const _ScaleIndicator({
		required this.cmPerPx,
		required this.color,
		required this.containScale,
		required this.zoom,
	});

	@override
	Widget build(BuildContext context) {
	// Arrow length is constant in overlay logical px; the number of image pixels it spans varies with zoom.
	const double arrowLenPx = 80; // logical overlay pixels
	// image pixels covered by the overlay length at current zoom
	final double imagePx = (arrowLenPx / (containScale * zoom));
	final double cmLen = cmPerPx * imagePx;
		return Container(
			padding: const EdgeInsets.all(8),
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(8),
				boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
			),
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					SizedBox(
						width: arrowLenPx + 20,
						height: arrowLenPx + 20,
						child: CustomPaint(
							painter: _HalfSquarePainter(color: color, size: arrowLenPx),
						),
					),
					const SizedBox(height: 6),
					Text('${cmLen.toStringAsFixed(1)} cm', style: const TextStyle(fontWeight: FontWeight.w600)),
				],
			),
		);
	}
}

class _HalfSquarePainter extends CustomPainter {
	final Color color;
	final double size;
	const _HalfSquarePainter({required this.color, required this.size});

	@override
	void paint(Canvas canvas, Size s) {
		final paint = Paint()
			..color = color
			..strokeWidth = 2
			..style = PaintingStyle.stroke;
		// Draw an L shape (half square)
		final origin = Offset(10, s.height - 10);
		canvas.drawLine(origin, origin + Offset(size, 0), paint); // horizontal
		canvas.drawLine(origin, origin - Offset(0, size), paint); // vertical
		// Arrows at ends
		_drawArrow(canvas, origin + Offset(size, 0), const Offset(-12, -6), const Offset(-12, 6), paint);
		_drawArrow(canvas, origin - Offset(0, size), const Offset(-6, 12), const Offset(6, 12), paint);
	}

	void _drawArrow(Canvas canvas, Offset tip, Offset wing1, Offset wing2, Paint paint) {
		canvas.drawLine(tip, tip + wing1, paint);
		canvas.drawLine(tip, tip + wing2, paint);
	}

	@override
	bool shouldRepaint(covariant _HalfSquarePainter oldDelegate) => false;
}

