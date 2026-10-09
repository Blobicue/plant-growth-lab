#include "gdextension_interface.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef union { uint64_t align[16]; unsigned char bytes[128]; } Slot;
typedef struct {uint32_t *storage,*a,*b,cap,nx,ny,nz,count; int ready;} Field;
static GDExtensionInterfaceGetProcAddress get;
static GDExtensionClassLibraryPtr library;
static GDExtensionInterfaceStringNameNewWithUtf8Chars sn;
static GDExtensionInterfaceVariantConstruct construct;
static GDExtensionInterfaceVariantDestroy destroy;
static GDExtensionInterfaceVariantCall vcall;
static GDExtensionInterfaceGetVariantFromTypeConstructor from;
static GDExtensionInterfaceGetVariantToTypeConstructor to;
static GDExtensionInterfaceVariantGetPtrDestructor destructor;
static GDExtensionInterfacePackedByteArrayOperatorIndex index_w;
static GDExtensionInterfacePackedByteArrayOperatorIndexConst index_r;
static GDExtensionInterfaceClassdbConstructObject3 new_object;
static GDExtensionInterfaceObjectSetInstance set_instance;
static Slot class_name,parent_name,method_name,size_name,resize_name,empty_name,empty_string;
static int64_t size_of(GDExtensionConstVariantPtr v){Slot result;GDExtensionCallError error;vcall((void*)v,&size_name,0,0,&result,&error);int64_t n=0;to(GDEXTENSION_VARIANT_TYPE_INT)(&n,&result);destroy(&result);return n;}
static void pack(GDExtensionVariantPtr ret,const void *data,int64_t bytes){
 Slot array,amount,ignored,native;GDExtensionCallError error;construct(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,&array,0,0,&error);from(GDEXTENSION_VARIANT_TYPE_INT)(&amount,&bytes);const void *args[]={&amount};vcall(&array,&resize_name,args,1,&ignored,&error);destroy(&ignored);destroy(&amount);to(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)(&native,&array);
 if(bytes)memcpy(index_w(&native,0),data,(size_t)bytes);
 from(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)(ret,&native);destructor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)(&native);destroy(&array);
}
static void diffuse(Field *f){
 for(int i=0;i<f->count;i++){
  int nx=f->nx,nz=f->nz,ny=f->ny,plane=nx*nz;int x=i%nx,z=(i/nx)%nz,y=i/plane;int adjacent[6]={x>0?i-1:-1,x+1<nx?i+1:-1,z>0?i-nx:-1,z+1<nz?i+nx:-1,y>0?i-plane:-1,y+1<ny?i+plane:-1};
  for(int k=0;k<2;k++){
   int64_t v=f->a[2*i+k],delta=0;
   for(int j=0;j<6;j++)if(adjacent[j]>=0){int64_t d=(int64_t)f->a[2*adjacent[j]+k]-v;delta+=d*(k==0?3:2)/100;}
   f->b[2*i+k]=(uint32_t)(v+delta);
  }
 }
 uint32_t *swap=f->a;f->a=f->b;f->b=swap;
}
static void transact(void *userdata,void *instance,const GDExtensionConstVariantPtr *args,GDExtensionInt argc,GDExtensionVariantPtr ret,GDExtensionCallError *error){
 Field *f=instance;error->error=GDEXTENSION_CALL_OK;
 if(argc!=1){error->error=GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;pack(ret,0,0);return;}
 int64_t bytes=size_of(args[0]);if(bytes<4){error->error=GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;pack(ret,0,0);return;}Slot native;to(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)(&native,(void*)args[0]);const uint32_t *r=(const uint32_t*)index_r(&native,0);uint32_t *out=0;size_t count=0;
 if(bytes>=20 && r[0]==0){
 uint64_t cells=(uint64_t)r[2]*r[3]*r[4];
 if(!cells || cells>500000 || !r[2] || !r[3] || !r[4] || bytes!=20+(int64_t)cells*8 || r[1]>1000000000){error->error=GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;pack(ret,0,0);destructor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)(&native);return;}
 f->cap=r[1];f->nx=r[2];f->ny=r[3];f->nz=r[4];f->count=(uint32_t)cells;free(f->storage);f->storage=calloc(cells*4,4);f->a=f->storage;f->b=f->storage+cells*2;memcpy(f->a,r+5,cells*8);f->ready=1;
}
 else if(bytes==4 && r[0]==2 && f->ready){pack(ret,f->a,(f->count*8));destructor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)(&native);return;}
 else if(bytes>=20 && r[0]==1 && f->ready){
  const uint32_t *req=r+1;uint32_t ec=req[0],qc=req[1];int valid=ec<=513 && qc<=3584 && bytes==(int64_t)(20+ec*16+qc*4);
  if(valid)for(uint32_t j=0;j<ec;j++){const uint32_t *cmd=req+4+j*4;if(cmd[0]>=f->count || cmd[1]>f->cap || cmd[2]>f->cap || cmd[3]>1)valid=0;}
  if(valid)for(uint32_t j=0;j<qc;j++)if(req[4+ec*4+j]>=f->count)valid=0;
  if(!valid){error->error=GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;pack(ret,0,0);destructor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)(&native);return;}
  count=8+ec*2+qc*2;out=calloc(count,4);diffuse(f);
  for(uint32_t j=0;j<ec;j++){
   const uint32_t *cmd=req+4+j*4;
   for(int k=0;k<2;k++){uint32_t *v=f->a+cmd[0]*2+k,want=cmd[k+1],available=cmd[3]?f->cap-*v:*v,actual=want<available?want:available;*v=cmd[3]?*v+actual:*v-actual;out[8+j*2+k]=actual;}
  }
  for(uint32_t j=0;j<qc;j++)for(int k=0;k<2;k++)out[8+ec*2+j*2+k]=f->a[req[4+ec*4+j]*2+k];
  uint64_t sums[2]={0,0};uint32_t low[2]={f->cap,f->cap},high[2]={0,0};
  for(int i=0;i<f->count;i++)for(int k=0;k<2;k++){uint32_t v=f->a[i*2+k];sums[k]+=v;if(v<low[k])low[k]=v;if(v>high[k])high[k]=v;}
  for(int k=0;k<2;k++){out[k]=(uint32_t)sums[k];out[k+2]=low[k];out[k+4]=high[k];out[k+6]=(uint32_t)(sums[k]>>32);}
 }else{error->error=GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;}
 pack(ret,out,count*4);free(out);destructor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)(&native);
}
static void ptrcall(void *user,void *instance,const GDExtensionConstTypePtr *args,GDExtensionTypePtr ret){Slot v,result;from(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)(&v,(void*)args[0]);const void *argv[]={&v};GDExtensionCallError error;transact(user,instance,argv,1,&result,&error);to(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)(ret,&result);destroy(&v);destroy(&result);}
static GDExtensionObjectPtr create(void *unused,GDExtensionBool notify){void *object=new_object(&parent_name);Field *f=calloc(1,sizeof(Field));set_instance(object,&class_name,f);return object;}
static void release(void *unused,void *instance){Field *f=instance;free(f->storage);free(f);}
static void initialize(void *unused,GDExtensionInitializationLevel level){
 if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;
 sn(&class_name,"NativeResourceField");sn(&parent_name,"RefCounted");sn(&method_name,"transact");sn(&size_name,"size");sn(&resize_name,"resize");sn(&empty_name,"");((GDExtensionInterfaceStringNewWithUtf8Chars)get("string_new_with_utf8_chars"))(&empty_string,"");
 GDExtensionClassCreationInfo6 info={0};info.is_exposed=1;info.icon_path=&empty_string;info.create_instance_func=create;info.free_instance_func=release;
 ((GDExtensionInterfaceClassdbRegisterExtensionClass6)get("classdb_register_extension_class6"))(library,&class_name,&parent_name,&info);
 GDExtensionPropertyInfo prop={0};prop.type=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY;prop.name=&empty_name;prop.class_name=&empty_name;prop.usage=6;prop.hint_string=&empty_string;
 GDExtensionClassMethodArgumentMetadata metadata=GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;GDExtensionClassMethodInfo method={0};method.name=&method_name;method.call_func=transact;method.ptrcall_func=ptrcall;method.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;method.has_return_value=1;method.return_value_info=&prop;method.argument_count=1;method.arguments_info=&prop;method.arguments_metadata=&metadata;
 ((GDExtensionInterfaceClassdbRegisterExtensionClassMethod)get("classdb_register_extension_class_method"))(library,&class_name,&method);
}
static void deinitialize(void *unused,GDExtensionInitializationLevel level){if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;((GDExtensionInterfaceClassdbUnregisterExtensionClass)get("classdb_unregister_extension_class"))(library,&class_name);destructor(GDEXTENSION_VARIANT_TYPE_STRING)(&empty_string);Slot *names[]={&class_name,&parent_name,&method_name,&size_name,&resize_name,&empty_name};for(int i=0;i<6;i++)destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(names[i]);}
#define LOAD(name,type) name=(type)get(#name)
__declspec(dllexport) GDExtensionBool resource_field_init(GDExtensionInterfaceGetProcAddress proc,GDExtensionClassLibraryPtr lib,GDExtensionInitialization *init){
 get=proc;library=lib;sn=(GDExtensionInterfaceStringNameNewWithUtf8Chars)get("string_name_new_with_utf8_chars");construct=(GDExtensionInterfaceVariantConstruct)get("variant_construct");destroy=(GDExtensionInterfaceVariantDestroy)get("variant_destroy");vcall=(GDExtensionInterfaceVariantCall)get("variant_call");from=(GDExtensionInterfaceGetVariantFromTypeConstructor)get("get_variant_from_type_constructor");to=(GDExtensionInterfaceGetVariantToTypeConstructor)get("get_variant_to_type_constructor");destructor=(GDExtensionInterfaceVariantGetPtrDestructor)get("variant_get_ptr_destructor");index_w=(GDExtensionInterfacePackedByteArrayOperatorIndex)get("packed_byte_array_operator_index");index_r=(GDExtensionInterfacePackedByteArrayOperatorIndexConst)get("packed_byte_array_operator_index_const");new_object=(GDExtensionInterfaceClassdbConstructObject3)get("classdb_construct_object3");set_instance=(GDExtensionInterfaceObjectSetInstance)get("object_set_instance");init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE;init->initialize=initialize;init->deinitialize=deinitialize;init->userdata=0;return 1;
}

