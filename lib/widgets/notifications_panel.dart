import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/notification_provider.dart';
import '../services/push_notification_service.dart';
import '../services/database_service.dart';
import '../screens/finance/request_detail_screen.dart';
import '../config/app_theme.dart';

class NotificationsPanel extends StatelessWidget {
 const NotificationsPanel({super.key});
 @override Widget build(BuildContext context){
  final provider=context.watch<NotificationProvider>();
  return SafeArea(child:Material(color:Colors.white,borderRadius:const BorderRadius.vertical(top:Radius.circular(20)),
   child:SizedBox(width:440,height:MediaQuery.sizeOf(context).height*.8,child:Column(children:[
    Padding(padding:const EdgeInsets.all(16),child:Wrap(
     spacing:12,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
      const Text('Notifications',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:AppTheme.primaryNavy)),
      if(provider.unreadCount>0)TextButton(onPressed:()=>provider.markAllAsRead(),child:const Text('Mark all as read')),
      IconButton(tooltip:'Close',onPressed:()=>Navigator.maybePop(context),icon:const Icon(Icons.close)),
     ],
    )),
    if(PushNotificationService().supported)Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Align(
     alignment:Alignment.centerLeft,child:TextButton.icon(icon:const Icon(Icons.notifications_active_outlined),
      label:const Text('Enable device notifications'),
      onPressed:()async{
       final ok=await PushNotificationService().enable();
       if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(ok?'Device notifications enabled.':PushNotificationService().lastError??'Unable to enable notifications.')));
      },
     ),
    )),
    if(provider.errorMessage!=null)Padding(padding:const EdgeInsets.all(12),child:Text(provider.errorMessage!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
    if(provider.isLoading)const LinearProgressIndicator(),
    const Divider(height:1),
    Expanded(child:provider.notifications.isEmpty
     ? Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
       const Icon(Icons.notifications_none_rounded,size:40,color:Colors.grey),
       const SizedBox(height:12),Text(provider.errorMessage==null?'You are all caught up.':'Notifications are unavailable.'),
       if(provider.errorMessage!=null)TextButton(onPressed:provider.refresh,child:const Text('Try again')),
      ]))
     : ListView.separated(
       itemCount:provider.notifications.length,separatorBuilder:(_,_)=>const Divider(height:1),
       itemBuilder:(context,index){
        final n=provider.notifications[index];
        return Dismissible(key:ValueKey(n.id),direction:DismissDirection.endToStart,
         background:Container(color:AppTheme.statusRejected,alignment:Alignment.centerRight,padding:const EdgeInsets.all(20),child:const Icon(Icons.delete_outline,color:Colors.white)),
         // Persist first. Failed deletes retain the item and display the provider error.
         confirmDismiss:(_)=>provider.deleteNotification(n.id),
         child:ListTile(
          contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:8),
          tileColor:n.isRead?null:const Color(0xffeff6ff),
          title:Text(n.title,style:TextStyle(fontWeight:n.isRead?FontWeight.w500:FontWeight.w700)),
          subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
           const SizedBox(height:6),Text(n.message),const SizedBox(height:6),
           Text(DateFormat('dd MMM, hh:mm a').format(n.createdAt.toLocal()),style:const TextStyle(fontSize:12,color:Colors.grey)),
          ]),
          onTap:()async{
           if(!n.isRead)await provider.markAsRead(n.id);
           if(n.relatedRequestId==null||!context.mounted)return;
           try{
            final request=await DatabaseService().getRequest(n.relatedRequestId!);
            if(context.mounted)await RequestDetailScreen.show(context,request);
           }catch(_){
            if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('This request is unavailable.')));
           }
          },
         ),
        );
       },
      )),
   ])),
  ));
 }
}

