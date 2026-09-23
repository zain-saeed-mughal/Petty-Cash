import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as gf;
import 'package:provider/provider.dart';
import 'package:petty_cash/config/app_theme.dart';
import 'package:petty_cash/providers/auth_provider.dart';
import 'package:petty_cash/providers/expense_provider.dart';
import 'package:petty_cash/providers/user_provider.dart';
import 'package:petty_cash/providers/notification_provider.dart';
import 'package:petty_cash/models/user_model.dart';
import 'package:petty_cash/models/expense_request_model.dart';
import 'package:petty_cash/models/notification_model.dart';
import 'package:petty_cash/screens/auth/login_screen.dart';
import 'package:petty_cash/screens/reports/monthly_reporting_screen.dart';
import 'package:petty_cash/screens/super_admin/analytics_screen.dart';
import 'package:petty_cash/screens/finance/request_detail_screen.dart';
import 'package:petty_cash/screens/finance/payment_history_screen.dart';
import 'package:petty_cash/screens/finance/pending_requests_screen.dart';
import 'package:petty_cash/screens/admin/all_transactions_screen.dart';
import 'package:petty_cash/screens/admin/user_management_screen.dart';
import 'package:petty_cash/screens/office_boy/my_requests_screen.dart';
import 'package:petty_cash/screens/office_boy/new_request_screen.dart';
import 'package:petty_cash/widgets/notifications_panel.dart';
import 'package:petty_cash/widgets/rejection_reason_dialog.dart';

final dir=Directory('${Directory.current.path}/.dart_tool/review_current');
final staff=AppUser(uid:'staff',name:'Muhammad Abdullah Khan',email:'abdullah@example.test',role:UserRole.officeBoy,createdAt:DateTime(2026));
final manager=AppUser(uid:'manager',name:'Sara Ahmed',email:'sara@example.test',role:UserRole.superAdmin,createdAt:DateTime(2026));
final rows=List.generate(4,(i)=>ExpenseRequest(id:'REQ-1234567$i',requestedBy:'staff',requesterName:staff.name,requesterEmail:staff.email,itemDescription:'Office stationery and printer service',amount:12500.50+i*1000,reason:'Paper and printer maintenance for the office.',billImageUrl:'https://example.test/receipt.png',status:RequestStatus.values[i],createdAt:DateTime.now(),updatedAt:DateTime.now()));
class A extends ChangeNotifier implements AuthProvider {
 AppUser user=manager;
 @override AppUser get currentUser=>user;
 @override bool get isLoading=>false;
 @override String? get errorMessage=>null;
 @override dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
class E extends ChangeNotifier implements ExpenseProvider {
 @override List<ExpenseRequest> get allRequests=>rows;
 @override List<ExpenseRequest> get filteredAllTransactions=>rows;
 @override List<ExpenseRequest> getMyRequests(String uid)=>rows;
 @override List<ExpenseRequest> get pendingRequests=>rows.where((r)=>r.isPending).toList();
 @override List<ExpenseRequest> get paymentHistory=>rows.where((r)=>!r.isPending).toList();
 @override double get totalSpent=>29001;
 @override double get pendingAmount=>12500.50;
 @override int get approvedCount=>2;
 @override int get pendingCount=>1;
 @override int get rejectedCount=>1;
 @override int get totalTransactionsCount=>4;
 @override double get approvalRate=>66.67;
 @override bool get isLoading=>false;
 @override String? get errorMessage=>null;
 @override dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
class U extends ChangeNotifier implements UserProvider {
 @override List<AppUser> get allUsers=>[staff,manager];
 @override List<AppUser> getManageableUsers(AppUser user)=>allUsers;
 @override dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
class N extends ChangeNotifier implements NotificationProvider {
 @override List<AppNotification> get notifications=>[AppNotification(userId:'manager',title:'New Expense Request',message:'A new request is awaiting review.')];
 @override int get unreadCount=>1;
 @override dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
class Manifest implements AssetManifest {
 @override List<String> listAssets()=>['review/Inter-Regular.ttf'];
 @override dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
void main(){
 final binding=TestWidgetsFlutterBinding.ensureInitialized();
 testWidgets('Current screen layout evidence with real fonts',(t) async {
  await t.runAsync(() async {
   gf.assetManifest=Manifest(); GoogleFonts.config.allowRuntimeFetching=false;
   binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets',(data) async {
    final key=utf8.decode(data!.buffer.asUint8List());
    final path=key.startsWith('review/')?'${dir.path}/fonts/${key.substring(7)}':'${Directory.current.path}/build/unit_test_assets/$key';
    final file=File(path);return await file.exists()?ByteData.sublistView(await file.readAsBytes()):null;
   });
   for(final family in ['ReviewRoboto','Roboto']){final f=FontLoader(family)..addFont(File('${dir.path}/fonts/Roboto-Regular.ttf').readAsBytes().then(ByteData.sublistView));await f.load();}
   final icons=FontLoader('MaterialIcons')..addFont(File('build/unit_test_assets/fonts/MaterialIcons-Regular.otf').readAsBytes().then(ByteData.sublistView));await icons.load();
   AppTheme.lightTheme;await GoogleFonts.pendingFonts();
  });
  final base=AppTheme.lightTheme;
  // Explicitly supply production-like Roboto fallback for styles without a family,
  // otherwise Flutter's Ahem testing font distorts button widths.
  ButtonStyle? normalize(ButtonStyle? s)=>s?.copyWith(textStyle:WidgetStatePropertyAll((s.textStyle?.resolve({})??const TextStyle()).copyWith(fontFamily:'ReviewRoboto')));
  final theme=base.copyWith(appBarTheme:base.appBarTheme.copyWith(titleTextStyle:base.appBarTheme.titleTextStyle?.copyWith(fontFamily:'ReviewRoboto')),
    textButtonTheme:TextButtonThemeData(style:normalize(base.textButtonTheme.style)),
    elevatedButtonTheme:ElevatedButtonThemeData(style:normalize(base.elevatedButtonTheme.style)),
    outlinedButtonTheme:OutlinedButtonThemeData(style:normalize(base.outlinedButtonTheme.style)));
  final a=A(),e=E(),u=U(),n=N();final key=GlobalKey();final results=<Map<String,dynamic>>[];
  final screens=<String,Widget Function()>{
   'login':()=>const LoginScreen(),'reports':()=>const MonthlyReportingScreen(),'analytics':()=>const AnalyticsScreen(),
   'transactions':()=>const AllTransactionsScreen(),'users':()=>const UserManagementScreen(),'pending':()=>const PendingRequestsScreen(),
   'history':()=>const PaymentHistoryScreen(),'my_requests':()=>const MyRequestsScreen(),'new_request':()=>const NewRequestScreen(),
   'detail':()=>RequestDetailScreen(request:rows.first.copyWith(billImageUrl:'')),
   'notifications':()=>const NotificationsPanel(),'reject':()=>RejectionReasonDialog(requestTitle:rows.first.itemDescription,amount:rows.first.amount),
  };
  for(final size in [const Size(320,568),const Size(360,800),const Size(390,844),const Size(768,1024),const Size(1024,768),const Size(1440,900)]){
   for(final scale in [1.0,if(size.width==360||size.width==1024)1.5]){
    t.view.physicalSize=size;t.view.devicePixelRatio=1;
    for(final entry in screens.entries){
     a.user=entry.key=='new_request'||entry.key=='my_requests'?staff:manager;
     final errors=<String>[];final original=FlutterError.onError;FlutterError.onError=(d){if(!d.toString().contains('HTTP request failed')&&!d.toString().contains('Invalid argument(s): No host specified'))errors.add(d.toString());};
     final name='${entry.key}_${size.width.toInt()}_$scale';
     final child=entry.value();
     final standalone=['login','detail','reject','notifications'].contains(entry.key);
     Widget home=standalone?(['login','detail'].contains(entry.key)?child:Scaffold(body:Align(alignment:Alignment.bottomCenter,child:child))):Scaffold(appBar:AppBar(title:const Text('Petty Cash')),body:Row(children:[if(size.width>=768)SizedBox(width:size.width>=1024?201:73),Expanded(child:child)]),bottomNavigationBar:size.width<768?const SizedBox(height:80):null);
     await t.pumpWidget(MultiProvider(providers:[ChangeNotifierProvider<AuthProvider>.value(value:a),ChangeNotifierProvider<ExpenseProvider>.value(value:e),ChangeNotifierProvider<UserProvider>.value(value:u),ChangeNotifierProvider<NotificationProvider>.value(value:n)],child:RepaintBoundary(key:key,child:MaterialApp(debugShowCheckedModeBanner:false,theme:theme,builder:(c,w)=>MediaQuery(data:MediaQuery.of(c).copyWith(textScaler:TextScaler.linear(scale)),child:w!),home:home))));
     await t.pump(const Duration(seconds:1));
     if(['reports','detail','notifications','history'].contains(entry.key)&&[360.0,1024.0].contains(size.width)){
      await t.runAsync(()async{final b=key.currentContext!.findRenderObject() as RenderRepaintBoundary;final img=await b.toImage();final bytes=await img.toByteData(format:ui.ImageByteFormat.png);await File('${dir.path}/$name.png').writeAsBytes(bytes!.buffer.asUint8List());img.dispose();});
     }
     for(final s in t.stateList<ScrollableState>(find.byType(Scrollable)).toList()){
      if(s.position.axis!=Axis.vertical)continue;
      for(int i=0;i<15&&s.position.pixels<s.position.maxScrollExtent;i++){s.position.jumpTo((s.position.pixels+size.height*.7).clamp(0,s.position.maxScrollExtent));await t.pump(const Duration(milliseconds:200));}
     }
     await t.pumpWidget(const SizedBox.shrink());await t.pump(const Duration(milliseconds:400));FlutterError.onError=original;
     results.add({'case':name,'errors':errors.toSet().toList()});
    }
   }
  }
  await t.runAsync(()=>File('${dir.path}/layout_results.json').writeAsString(const JsonEncoder.withIndent('  ').convert(results)));
  t.view.resetPhysicalSize();t.view.resetDevicePixelRatio();
  expect(results.length,96);
 },timeout:const Timeout(Duration(minutes:5)));
}
