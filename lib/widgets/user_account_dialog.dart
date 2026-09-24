import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';

class UserAccountDialog extends StatefulWidget {
 final AppUser actor;
 final AppUser? user;
 const UserAccountDialog({super.key,required this.actor,this.user});
 @override State<UserAccountDialog> createState()=>_UserAccountDialogState();
}
class _UserAccountDialogState extends State<UserAccountDialog>{
 final _form=GlobalKey<FormState>();
 late final TextEditingController _name,_email;
 final _password=TextEditingController();
 late UserRole _role;
 late bool _active;
 bool _busy=false,_showPassword=false;
 String? _error;
 @override void initState(){
  super.initState();_name=TextEditingController(text:widget.user?.name);
  _email=TextEditingController(text:widget.user?.email);
  _role=widget.user?.role??UserRole.officeBoy;_active=widget.user?.isActive??true;
 }
 @override void dispose(){_name.dispose();_email.dispose();_password.dispose();super.dispose();}
 Future<void> _save()async{
  if(_busy||!_form.currentState!.validate())return;
  final provider=context.read<UserProvider>();
  final name=_name.text.trim(),email=_email.text.trim().toLowerCase(),password=_password.text;
  setState((){_busy=true;_error=null;});
  final success=widget.user==null
   ? await provider.addUser(name:name,email:email,password:password,role:_role)
   : await provider.updateUser(widget.user!.copyWith(name:name,email:email,password:password.isEmpty?null:password,role:_role,isActive:_active));
  if(!mounted)return;
  setState(()=>_busy=false);
  if(success) {
    Navigator.pop(context,{'name':name,'email':email,'password':password});
  } else {
    setState(()=>_error=provider.errorMessage??'Unable to save this account.');
  }
 }
 @override Widget build(BuildContext context){
  final roles=widget.actor.isSuperAdmin?UserRole.values:[UserRole.officeBoy,UserRole.finance];
  final self=widget.user?.uid==widget.actor.uid;
  return PopScope(canPop:!_busy,child:AlertDialog(
   title:Text(widget.user==null?'Create account':'Edit account'),
   content:SizedBox(width:440,child:SingleChildScrollView(child:Form(key:_form,child:Column(mainAxisSize:MainAxisSize.min,children:[
    TextFormField(controller:_name,enabled:!_busy,maxLength:120,decoration:const InputDecoration(labelText:'Full name'),
     validator:(v)=>v==null||v.trim().isEmpty?'Enter a name':null),
    const SizedBox(height:12),
    TextFormField(controller:_email,enabled:!_busy,keyboardType:TextInputType.emailAddress,autofillHints:const[AutofillHints.email],
     decoration:const InputDecoration(labelText:'Email address'),
     validator:(v)=>v==null||!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())?'Enter a valid email address':null),
    const SizedBox(height:16),
    TextFormField(controller:_password,enabled:!_busy,obscureText:!_showPassword,
     decoration:InputDecoration(labelText:widget.user==null?'Temporary password':'New password (optional)',
      helperText:'At least 12 characters',suffixIcon:IconButton(tooltip:_showPassword?'Hide password':'Show password',onPressed:()=>setState(()=>_showPassword=!_showPassword),icon:Icon(_showPassword?Icons.visibility_off:Icons.visibility))),
     validator:(v)=> (widget.user==null||(v?.isNotEmpty??false))&&(v?.length??0)<12?'Use at least 12 characters':null),
    const SizedBox(height:16),
    DropdownButtonFormField<UserRole>(initialValue:_role,isExpanded:true,decoration:const InputDecoration(labelText:'Role'),
     items:roles.map((r)=>DropdownMenuItem(value:r,child:Text(r.displayName,overflow:TextOverflow.ellipsis))).toList(),
     onChanged:_busy||self?null:(v)=>setState(()=>_role=v!)),
    if(widget.user!=null)SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Account active'),value:_active,
     onChanged:_busy||self?null:(v)=>setState(()=>_active=v)),
    if(_error!=null)Padding(padding:const EdgeInsets.only(top:16),child:Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
   ])))),
   actions:[
    TextButton(onPressed:_busy?null:()=>Navigator.pop(context),child:const Text('Cancel')),
    FilledButton(onPressed:_busy?null:_save,child:Text(_busy?'Saving…':'Save account')),
   ],
  ));
 }
}

