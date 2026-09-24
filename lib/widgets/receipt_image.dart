import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/storage_service.dart';

class ReceiptImage extends StatefulWidget {
 final String imageUrl;
 final BoxFit? fit;
 final Widget Function(BuildContext,String)? placeholder;
 final Widget Function(BuildContext,String,Object)? errorWidget;
 const ReceiptImage({super.key,required this.imageUrl,this.fit,this.placeholder,this.errorWidget});
 @override State<ReceiptImage> createState()=>_ReceiptImageState();
}
class _ReceiptImageState extends State<ReceiptImage> {
 late Future<String> _url;
 @override void initState(){super.initState();_resolve();}
 @override void didUpdateWidget(ReceiptImage old){super.didUpdateWidget(old);if(old.imageUrl!=widget.imageUrl)_resolve();}
 void _resolve(){_url=StorageService().resolveReceipt(widget.imageUrl);}
 Widget _error(Object e)=>widget.errorWidget?.call(context,widget.imageUrl,e)??Center(child:Column(
  mainAxisSize:MainAxisSize.min,children:[
   const Icon(Icons.broken_image_outlined),const SizedBox(height:8),
   const Text('Receipt unavailable',textAlign:TextAlign.center),
   TextButton(onPressed:()=>setState(_resolve),child:const Text('Try again')),
  ]));
 @override Widget build(BuildContext context)=>FutureBuilder<String>(future:_url,builder:(context,snapshot){
  if(snapshot.hasError)return _error(snapshot.error!);
  if(!snapshot.hasData)return widget.placeholder?.call(context,widget.imageUrl)??const Center(child:CircularProgressIndicator());
  final url=snapshot.data!;
  if(url.startsWith('data:image/')){
   try{return Image.memory(base64Decode(url.split(',').last),fit:widget.fit,errorBuilder:(_,e,_)=>_error(e));}
   catch(e){return _error(e);}
  }
  return CachedNetworkImage(imageUrl:url,fit:widget.fit,
    placeholder:widget.placeholder,errorWidget:(_,_,e)=>_error(e));
 });
}

