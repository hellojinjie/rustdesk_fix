import 'dart:convert';

import 'package:flutter/material.dart';

import '../../common.dart';
import '../../models/platform_model.dart';

const _managedDeviceHostsKey = 'managed-device-hosts';

class ManagedDevice {
  final String name;
  final String ip;

  const ManagedDevice({
    required this.name,
    required this.ip,
  });

  String get title => name.trim().isEmpty ? ip : name;

  Map<String, dynamic> toJson() => {
        'name': name,
        'ip': ip,
      };

  factory ManagedDevice.fromJson(Map<String, dynamic> json) {
    return ManagedDevice(
      name: _stringValue(json['name']).trim(),
      ip: _stringValue(json['ip']).trim(),
    );
  }
}

String _stringValue(dynamic value) {
  return value is String ? value : '';
}

class ManagedDeviceHomePage extends StatefulWidget {
  const ManagedDeviceHomePage({Key? key}) : super(key: key);

  @override
  State<ManagedDeviceHomePage> createState() => _ManagedDeviceHomePageState();
}

class _ManagedDeviceHomePageState extends State<ManagedDeviceHomePage> {
  List<ManagedDevice> _devices = const [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  void _loadDevices() {
    final raw = bind.mainGetLocalOption(key: _managedDeviceHostsKey);
    final devices = <ManagedDevice>[];

    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map<String, dynamic>) {
              continue;
            }
            final device = ManagedDevice.fromJson(item);
            if (device.ip.isEmpty) {
              continue;
            }
            devices.add(device);
          }
        }
      } catch (e) {
        debugPrint('Failed to parse managed device hosts: $e');
      }
    }

    setState(() {
      _devices = devices;
    });
  }

  Future<void> _saveDevices(List<ManagedDevice> devices) async {
    await bind.mainSetLocalOption(
      key: _managedDeviceHostsKey,
      value: jsonEncode(devices.map((device) => device.toJson()).toList()),
    );
    if (!mounted) return;
    setState(() {
      _devices = List.unmodifiable(devices);
    });
  }

  Future<void> _showDeviceDialog({ManagedDevice? device, int? index}) async {
    final nameController = TextEditingController(text: device?.name ?? '');
    final ipController = TextEditingController(text: device?.ip ?? '');
    String? nameErrorText;
    String? ipErrorText;

    final result = await showDialog<ManagedDevice>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(device == null ? '新增主机' : '修改主机'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: '主机名称',
                      hintText: '例如：办公室电脑',
                      errorText: nameErrorText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ipController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'IP 地址',
                      hintText: '例如：192.168.1.100',
                      errorText: ipErrorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final ip = ipController.text.trim();
                    if (name.isEmpty) {
                      setDialogState(() {
                        nameErrorText = '请输入主机名称';
                        ipErrorText = ip.isEmpty ? '请输入 IP 地址' : null;
                      });
                      return;
                    }
                    if (ip.isEmpty) {
                      setDialogState(() {
                        nameErrorText = null;
                        ipErrorText = '请输入 IP 地址';
                      });
                      return;
                    }
                    Navigator.of(context).pop(ManagedDevice(
                      name: name,
                      ip: ip,
                    ));
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    ipController.dispose();

    if (result == null) {
      return;
    }

    final next = List<ManagedDevice>.from(_devices);
    if (index == null) {
      next.add(result);
    } else {
      next[index] = result;
    }
    await _saveDevices(next);
  }

  Future<void> _deleteDevice(int index) async {
    final device = _devices[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除主机'),
          content: Text('确定要删除“${device.title}”吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final next = List<ManagedDevice>.from(_devices)..removeAt(index);
    await _saveDevices(next);
  }

  void _connectToDevice(ManagedDevice device) {
    connect(context, device.ip);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        centerTitle: false,
        title: const Text('远程设备'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '新增主机',
            onPressed: () => _showDeviceDialog(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth >= 720 ? 680.0 : 560.0;
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: _devices.isEmpty
                        ? _StateView(
                            icon: Icons.devices_other_rounded,
                            title: '暂无主机',
                            message: '请新增主机名称和 IP 地址，之后可从这里直接发起远控连接。',
                            primaryText: '新增主机',
                            onPrimary: () => _showDeviceDialog(),
                          )
                        : _DeviceList(
                            devices: _devices,
                            onAdd: () => _showDeviceDialog(),
                            onConnect: _connectToDevice,
                            onEdit: (index) => _showDeviceDialog(
                              device: _devices[index],
                              index: index,
                            ),
                            onDelete: _deleteDevice,
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: _devices.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showDeviceDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('新增'),
            ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  final List<ManagedDevice> devices;
  final VoidCallback onAdd;
  final ValueChanged<ManagedDevice> onConnect;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;

  const _DeviceList({
    required this.devices,
    required this.onAdd,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '设备列表',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${devices.length} 台已配置主机',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.textTheme.bodySmall?.color?.withOpacity(0.66),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '新增主机',
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(devices.length, (index) {
          final device = devices[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DeviceCard(
              device: device,
              onTap: () => onConnect(device),
              onEdit: () => onEdit(index),
              onDelete: () => onDelete(index),
            ),
          );
        }),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final ManagedDevice device;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DeviceCard({
    required this.device,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      elevation: theme.brightness == Brightness.dark ? 0 : 1.5,
      shadowColor: Colors.black.withOpacity(0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _DeviceIcon(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      device.ip,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color
                            ?.withOpacity(0.66),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '主机操作',
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('修改'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('删除'),
                  ),
                ],
              ),
              const SizedBox(width: 2),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '连接',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        Icons.desktop_windows_rounded,
        color: theme.colorScheme.primary,
        size: 28,
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String primaryText;
  final VoidCallback onPrimary;

  const _StateView({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryText,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 430),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 36, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.68),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onPrimary,
            child: Text(primaryText),
          ),
        ],
      ),
    );
  }
}
