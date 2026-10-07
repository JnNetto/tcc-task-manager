# flutter_local_notifications usa Gson com TypeToken para serializar notificações
# agendadas. O R8 remove assinaturas genéricas por padrão, causando
# IllegalStateException em runtime. As regras abaixo preservam o necessário.

-keepattributes Signature
-keepattributes *Annotation*

-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
