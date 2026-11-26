import 'package:flutter/material.dart';
import '../../../core/widgets/upload_image_picker.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/department.dart';
import '../../../models/doctor.dart';
import '../../../models/room.dart';
import '../../../repositories/department_repository.dart';
import '../../../repositories/doctor_repository.dart';
import '../../../repositories/room_repository.dart';

class DoctorFormPage extends StatefulWidget {
  const DoctorFormPage({
    super.key,
    this.doctor,
    this.doctorRepository,
    this.departmentRepository,
    this.roomRepository,
  });

  final Doctor? doctor;
  final DoctorRepository? doctorRepository;
  final DepartmentRepository? departmentRepository;
  final RoomRepository? roomRepository;

  bool get isEdit => doctor != null;

  @override
  State<DoctorFormPage> createState() => _DoctorFormPageState();
}

class _DoctorFormPageState extends State<DoctorFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final DoctorRepository _doctorRepository =
      widget.doctorRepository ?? DoctorRepository();
  late final DepartmentRepository _departmentRepository =
      widget.departmentRepository ?? DepartmentRepository();
  late final RoomRepository _roomRepository =
      widget.roomRepository ?? RoomRepository();

  late final TextEditingController _fullNameController;
  late final TextEditingController _qualificationController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _experienceYearsController;
  late final TextEditingController _consultationFeeController;
  late final TextEditingController _descriptionController;

  int? _selectedDepartmentId;
  int? _selectedRoomId;
  UploadImage? _selectedImage;

  List<Department> _departments = [];
  List<Room> _rooms = [];

  bool _isLoadingDepartments = true;
  bool _isLoadingRooms = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final d = widget.doctor;
    _fullNameController = TextEditingController(text: d?.fullName ?? '');
    _qualificationController =
        TextEditingController(text: d?.qualification ?? '');
    _emailController = TextEditingController(text: d?.email ?? '');
    _phoneController = TextEditingController(text: d?.phone ?? '');
    _experienceYearsController = TextEditingController(
      text: d != null ? d.experienceYears.toString() : '0',
    );
    _consultationFeeController = TextEditingController(
      text: d != null ? d.consultationFee.toInt().toString() : '',
    );
    _descriptionController = TextEditingController(text: d?.description ?? '');

    _selectedDepartmentId = d?.departmentId;

    _initData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _qualificationController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _experienceYearsController.dispose();
    _consultationFeeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await _loadDepartments();

    // Nếu sửa bác sĩ: đã có departmentId thì tải danh sách phòng của khoa đó
    if (widget.isEdit && _selectedDepartmentId != null) {
      await _loadRoomsForDepartment(
        _selectedDepartmentId!,
        targetRoomId: widget.doctor?.roomId,
      );
    }
  }

  Future<void> _loadDepartments() async {
    setState(() => _isLoadingDepartments = true);
    try {
      final list = await _departmentRepository.list();
      if (mounted) {
        setState(() {
          _departments = list;
          // Nếu đang thêm mới hoặc departmentId chưa chọn và list không rỗng thì không bắt buộc gán cứng
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tải danh sách chuyên khoa.'),
            backgroundColor: Color(0xffef4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingDepartments = false);
    }
  }

  /// Tải phòng theo khoa:
  /// - Chỉ hiển thị phòng isActive trong dropdown.
  /// - Khi sửa bác sĩ mà phòng hiện tại của họ không còn active: vẫn đưa phòng hiện tại vào danh sách
  ///   để hiển thị đúng, tránh crash DropdownButton, và cho phép đổi sang phòng khác.
  Future<void> _loadRoomsForDepartment(
    int departmentId, {
    int? targetRoomId,
  }) async {
    setState(() {
      _isLoadingRooms = true;
      _selectedRoomId = null;
    });

    try {
      final allRooms = await _roomRepository.getRooms(
        departmentId: departmentId,
      );

      // Lọc các phòng isActive = true
      final activeRooms = allRooms.where((r) => r.isActive).toList();

      // Kiểm tra khi sửa bác sĩ: nếu có phòng hiện tại
      if (targetRoomId != null) {
        final alreadyInActive = activeRooms.any((r) => r.id == targetRoomId);
        if (!alreadyInActive) {
          // Tìm phòng trong toàn bộ danh sách phòng của khoa
          final existing = allRooms.where((r) => r.id == targetRoomId).firstOrNull;
          final fallbackRoom = existing ??
              Room(
                id: targetRoomId,
                roomNumber: widget.doctor?.roomNumber ?? '?',
                floor: widget.doctor?.floor ?? 0,
                departmentId: departmentId,
                isActive: false,
              );
          // Thêm phòng hiện tại vào đầu danh sách để dropdown hiển thị hợp lệ
          activeRooms.insert(0, fallbackRoom);
        }
      }

      if (mounted) {
        setState(() {
          _rooms = activeRooms;
          // Chỉ set value cho dropdown nếu targetRoomId nằm trong danh sách
          if (targetRoomId != null &&
              activeRooms.any((r) => r.id == targetRoomId)) {
            _selectedRoomId = targetRoomId;
          } else {
            _selectedRoomId = null;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _rooms = []);
      }
    } finally {
      if (mounted) setState(() => _isLoadingRooms = false);
    }
  }

  void _onDepartmentChanged(int? newDepartmentId) {
    if (newDepartmentId == _selectedDepartmentId) return;

    setState(() {
      _selectedDepartmentId = newDepartmentId;
      _selectedRoomId = null;
      _rooms = [];
    });

    if (newDepartmentId != null) {
      _loadRoomsForDepartment(newDepartmentId);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final fee = double.parse(_consultationFeeController.text.trim());
      final exp = int.parse(_experienceYearsController.text.trim());

      final input = DoctorFormInput(
        fullName: _fullNameController.text.trim(),
        qualification: _qualificationController.text.trim().isEmpty
            ? null
            : _qualificationController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        departmentId: _selectedDepartmentId!,
        roomId: _selectedRoomId,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        experienceYears: exp,
        consultationFee: fee,
      );

      if (widget.isEdit) {
        await _doctorRepository.updateDoctor(
          widget.doctor!.id,
          input,
          imageBytes: _selectedImage?.bytes,
          imageFilename: _selectedImage?.filename,
          avatarUrl: _selectedImage?.url,
        );
      } else {
        await _doctorRepository.createDoctor(
          input,
          imageBytes: _selectedImage?.bytes,
          imageFilename: _selectedImage?.filename,
          avatarUrl: _selectedImage?.url,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEdit
                ? 'Cập nhật bác sĩ thành công.'
                : 'Thêm bác sĩ mới thành công.',
          ),
          backgroundColor: const Color(0xff10b981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException
          ? e.displayMessage
          : 'Không thể lưu thông tin bác sĩ. Vui lòng thử lại.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xffef4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEdit ? 'Sửa thông tin Bác sĩ' : 'Thêm Bác sĩ mới',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UploadImagePicker(
                currentImageUrl: _doctorRepository.imageUrl(widget.doctor?.avatarUrl),
                selection: _selectedImage,
                enabled: !_isSubmitting,
                maxMegabytes: 2,
                allowWebp: true,
                onChanged: (selection) => setState(() => _selectedImage = selection),
              ),
              const SizedBox(height: 24),

              TextFormField(
                key: const ValueKey('doctor-name-field'),
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: 'Họ và tên bác sĩ *',
                  hintText: 'Nhập họ và tên đầy đủ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập họ và tên bác sĩ';
                  }
                  if (val.trim().length > 100) {
                    return 'Họ và tên không được vượt quá 100 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                key: const ValueKey('doctor-qualification-field'),
                controller: _qualificationController,
                decoration: InputDecoration(
                  labelText: 'Bằng cấp / Học vị',
                  hintText: 'Ví dụ: ThS, BS.CKI, PGS.TS...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.school_outlined),
                ),
                validator: (val) {
                  if (val != null && val.trim().length > 100) {
                    return 'Bằng cấp không được vượt quá 100 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('doctor-email-field'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'bacsi@example.com',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          final emailRegExp = RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                          );
                          if (!emailRegExp.hasMatch(val.trim())) {
                            return 'Email không đúng định dạng';
                          }
                          if (val.trim().length > 100) {
                            return 'Email tối đa 100 ký tự';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('doctor-phone-field'),
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Số điện thoại',
                        hintText: '09xxxxxxxx',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          final phoneRegExp = RegExp(r'^0\d{9}$');
                          if (!phoneRegExp.hasMatch(val.trim())) {
                            return 'SĐT gồm 10 số (bắt đầu bằng 0)';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                key: const ValueKey('doctor-department-dropdown'),
                initialValue: _selectedDepartmentId,
                decoration: InputDecoration(
                  labelText: 'Chuyên khoa *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.local_hospital_outlined),
                ),
                hint: _isLoadingDepartments
                    ? const Text('Đang tải danh sách khoa...')
                    : const Text('Chọn chuyên khoa'),
                items: _departments.map((dept) {
                  return DropdownMenuItem<int>(
                    value: dept.id,
                    child: Text(dept.name),
                  );
                }).toList(),
                onChanged: _onDepartmentChanged,
                validator: (val) {
                  if (val == null) {
                    return 'Vui lòng chọn chuyên khoa';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                key: const ValueKey('doctor-room-dropdown'),
                initialValue: _selectedRoomId,
                decoration: InputDecoration(
                  labelText: 'Phòng khám',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.meeting_room_outlined),
                  suffixIcon: _isLoadingRooms
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                hint: _selectedDepartmentId == null
                    ? const Text('Vui lòng chọn chuyên khoa trước')
                    : _isLoadingRooms
                        ? const Text('Đang tải danh sách phòng...')
                        : _rooms.isEmpty
                            ? const Text('Khoa này chưa có phòng khám nào')
                            : const Text('Chọn phòng khám (tùy chọn)'),
                items: _rooms.map((room) {
                  final inactiveTag = !room.isActive ? ' - (Không hoạt động)' : '';
                  return DropdownMenuItem<int>(
                    value: room.id,
                    child: Text('${room.displayLabel}$inactiveTag'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedRoomId = val),
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('doctor-experience-field'),
                      controller: _experienceYearsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Năm kinh nghiệm *',
                        hintText: '0 - 70',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.work_history_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Nhập năm kinh nghiệm';
                        }
                        final num = int.tryParse(val.trim());
                        if (num == null || num < 0 || num > 70) {
                          return 'Từ 0 đến 70 năm';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('doctor-fee-field'),
                      controller: _consultationFeeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Phí khám (VNĐ) *',
                        hintText: '150000',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.payments_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Nhập phí khám';
                        }
                        final num = double.tryParse(val.trim());
                        if (num == null || num <= 0) {
                          return 'Phí khám phải > 0';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                key: const ValueKey('doctor-description-field'),
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Mô tả quá trình công tác / tiểu sử',
                  hintText: 'Nhập thông tin giới thiệu về bác sĩ...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val != null && val.trim().length > 2000) {
                    return 'Mô tả không được vượt quá 2000 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),

              FilledButton(
                key: const ValueKey('submit-doctor-button'),
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.isEdit ? 'Lưu thay đổi' : 'Tạo bác sĩ mới',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
