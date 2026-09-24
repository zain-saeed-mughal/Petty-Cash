import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/expense_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/expense_request_model.dart';
import '../../config/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../finance/request_detail_screen.dart';

class MonthlyReportingScreen extends StatefulWidget {
 const MonthlyReportingScreen({super.key});
 @override State<MonthlyReportingScreen> createState()=>_MonthlyReportingScreenState();
}
class _MonthlyReportingScreenState extends State<MonthlyReportingScreen> {
 DateTime _month=DateTime.now();
 String? _user;
 RequestStatus? _status;
 int _page=0;
 final _money=NumberFormat.currency(symbol:'Rs. ',decimalDigits:2);
 void _move(int delta)=>setState((){_month=DateTime(_month.year,_month.month+delta);_page=0;});
 bool _matches(ExpenseRequest r)=> (_user==null||r.requestedBy==_user)&&(_status==null||r.status==_status);
 bool _inMonth(ExpenseRequest r,DateTime month){
  if(r.isPaid&&r.paidAt==null)return false;
  final d=r.reportingDate;
  return d.year==month.year&&d.month==month.month;
 }
 @override Widget build(BuildContext context){
  final expense=context.watch<ExpenseProvider>();
  final users=context.watch<UserProvider>().allUsers;
  final rows=expense.allRequests.where((r)=>_matches(r)&&_inMonth(r,_month)).toList();
  final previous=DateTime(_month.year,_month.month-1);
  final paid=rows.where((r)=>r.isPaid).fold(0.0,(sum,r)=>sum+r.amount);
  final previousPaid=expense.allRequests.where((r)=>r.isPaid&&_matches(r)&&_inMonth(r,previous)).fold(0.0,(sum,r)=>sum+r.amount);
  final undated=expense.allRequests.where((r)=>r.isPaid&&r.paidAt==null&&_matches(r)).length;
  final pages=math.max(1,(rows.length/10).ceil());
  final page=math.min(_page,pages-1);
  final visible=rows.skip(page*10).take(10).toList();
  return LayoutBuilder(builder:(context,bounds){
   final inset=bounds.maxWidth>=900?32.0:16.0;
   return ListView(padding:EdgeInsets.all(inset),children:[
    Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1200),child:Column(
     crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Monthly Reports',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),
      const SizedBox(height:8),
      const Text('Paid amounts use the payment date. Other requests use their submission date.'),
      const SizedBox(height:24),
      Card(child:Padding(padding:const EdgeInsets.all(16),child:LayoutBuilder(builder:(context,c){
       final width=math.min(280.0,c.maxWidth);
       return Wrap(spacing:16,runSpacing:12,crossAxisAlignment:WrapCrossAlignment.center,children:[
        SizedBox(width:width,child:Row(children:[
         IconButton(tooltip:'Previous month',onPressed:()=>_move(-1),icon:const Icon(Icons.chevron_left)),
         Expanded(child:Text(DateFormat('MMMM yyyy').format(_month),textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w700))),
         IconButton(tooltip:'Next month',onPressed:()=>_move(1),icon:const Icon(Icons.chevron_right)),
        ])),
        SizedBox(width:width,child:DropdownButtonFormField<String>(
         initialValue:users.any((u)=>u.uid==_user)?_user:null,isExpanded:true,
         decoration:const InputDecoration(labelText:'Requester'),
         items:[const DropdownMenuItem<String>(value:null,child:Text('All users')),
          ...users.map((u)=>DropdownMenuItem(value:u.uid,child:Text(u.name,maxLines:1,overflow:TextOverflow.ellipsis)))],
         onChanged:(v)=>setState((){_user=v;_page=0;}),
        )),
        SizedBox(width:width,child:DropdownButtonFormField<RequestStatus>(
         initialValue:_status,isExpanded:true,decoration:const InputDecoration(labelText:'Status'),
         items:[const DropdownMenuItem<RequestStatus>(value:null,child:Text('All statuses')),
          ...RequestStatus.values.map((s)=>DropdownMenuItem(value:s,child:Text(s.displayName)))],
         onChanged:(v)=>setState((){_status=v;_page=0;}),
        )),
       ]);
      }))),
      const SizedBox(height:20),
      if(expense.errorMessage!=null) Padding(padding:const EdgeInsets.only(bottom:16),child:Text('Data could not be refreshed. Displayed values may be out of date.',style:TextStyle(color:Theme.of(context).colorScheme.error))),
      LayoutBuilder(builder:(context,c){
       final scale=MediaQuery.textScalerOf(context).scale(1);
       final columns=c.maxWidth>=1100&&scale<1.3?4:c.maxWidth>=600?2:1;
       final width=(c.maxWidth-(columns-1)*16)/columns;
       return Wrap(spacing:16,runSpacing:16,children:[
        _metric(width,'Total paid',_money.format(paid),Icons.payments_outlined,AppTheme.accentTeal,
         previousPaid>0?'${(((paid-previousPaid)/previousPaid)*100).toStringAsFixed(1)}% vs previous month':'No previous paid amount'),
        _metric(width,'Requests in view',rows.length.toString(),Icons.receipt_long_outlined,AppTheme.primaryBlue,'All active filters applied'),
        _metric(width,'Pending',rows.where((r)=>r.isPending).length.toString(),Icons.schedule_outlined,AppTheme.statusPending,'Awaiting a decision'),
        _metric(width,'Rejected',rows.where((r)=>r.isRejected).length.toString(),Icons.cancel_outlined,AppTheme.statusRejected,'Review reasons in request details'),
       ]);
      }),
      if(undated>0) Padding(padding:const EdgeInsets.only(top:16),child:Text('$undated historical payment(s) have no verified payment date and are excluded from monthly totals.')),
      const SizedBox(height:24),
      Text('Request details',style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:12),
      if(rows.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(32),child:Center(child:Text('No requests match these filters.')))),
      ...visible.map((r)=>Padding(padding:const EdgeInsets.only(bottom:12),child:Card(child:InkWell(
       borderRadius:BorderRadius.circular(20),
       onTap:()=>RequestDetailScreen.show(context,r),
       child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Wrap(spacing:12,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
         Text(r.displayId,style:const TextStyle(fontWeight:FontWeight.w700)),
         StatusBadge(status:r.status),
         Text(DateFormat('dd MMM yyyy').format(r.reportingDate),style:const TextStyle(color:Color(0xff64748b))),
        ]),
        const SizedBox(height:12),
        Text(r.itemDescription,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w600)),
        const SizedBox(height:8),Text(r.requesterName),
        const SizedBox(height:12),
        Text(_money.format(r.amount),style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:AppTheme.primaryBlue)),
       ])),
      )))),
      if(rows.isNotEmpty) Wrap(spacing:12,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
       Text('${rows.length} requests · Page ${page+1} of $pages'),
       OutlinedButton(onPressed:page>0?()=>setState(()=>_page=page-1):null,child:const Text('Previous')),
       OutlinedButton(onPressed:page+1<pages?()=>setState(()=>_page=page+1):null,child:const Text('Next')),
      ]),
     ],
    ))),
   ]);
  });
 }
 Widget _metric(double width,String title,String value,IconData icon,Color color,String note)=>SizedBox(
  width:width,child:Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(
   crossAxisAlignment:CrossAxisAlignment.start,children:[
    Icon(icon,color:color),const SizedBox(height:12),
    Text(title,style:const TextStyle(color:Color(0xff64748b),fontWeight:FontWeight.w600)),
    const SizedBox(height:8),Text(value,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800,color:AppTheme.primaryNavy)),
    const SizedBox(height:8),Text(note,style:const TextStyle(fontSize:12,color:Color(0xff64748b))),
   ],
  ))),
 );
}

