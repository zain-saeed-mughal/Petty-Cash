import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../providers/user_provider.dart';

class DataStatusView extends StatelessWidget {
 final Widget child;
 const DataStatusView({super.key,required this.child});
 @override Widget build(BuildContext context){
  final expenses=context.watch<ExpenseProvider>();
  final users=context.watch<UserProvider>();
  final error=expenses.errorMessage??users.errorMessage;
  final loading=expenses.isLoading||users.isLoading;
  void retry(){expenses.refresh();users.refresh();}
  if(error!=null&&expenses.allRequests.isEmpty){
   return Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Icon(Icons.cloud_off_outlined,size:48),const SizedBox(height:16),
    const Text('Unable to load your workspace',style:TextStyle(fontSize:20,fontWeight:FontWeight.w700)),
    const SizedBox(height:8),Text(error,textAlign:TextAlign.center),
    const SizedBox(height:16),FilledButton(onPressed:retry,child:const Text('Try again')),
   ])));
  }
  if(loading&&expenses.allRequests.isEmpty){
   return const Center(child:CircularProgressIndicator());
  }
  return Column(children:[
   if(loading)const LinearProgressIndicator(minHeight:2),
   if(error!=null)Material(color:Theme.of(context).colorScheme.errorContainer,child:Padding(
    padding:const EdgeInsets.all(12),child:Wrap(spacing:12,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
     const Text('Unable to refresh. Displayed data may be out of date.'),
     TextButton(onPressed:retry,child:const Text('Retry')),
    ]),
   )),
   Expanded(child:child),
  ]);
 }
}

