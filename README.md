# Honeypot
¿Alguna vez te has preguntado qué pasa cuando dejas un puerto abierto en internet? Hoy decidí no quedarme con la duda y construí un SSH Honeypot (tarro de miel) totalmente funcional usando solamente Bash y Socat.



💡 El Desafío:

Al principio intenté usar netcat, pero me topé con limitaciones importantes: no soportaba múltiples conexiones simultáneas y la interacción no se sentía "real".



🛠️ La Solución:

Evolucioné el script para usar socat, lo que me permitió:



Forking de procesos: Soportar múltiples "atacantes" al mismo tiempo sin bloquear el puerto.



Simulación Realista: Recrear el comportamiento de un servidor Ubuntu (prompts de login as: y password:) con pausas dramáticas para simular la verificación de credenciales.



Cross-Platform: Solucionar problemas de compatibilidad con clientes Windows (CRLF) y Linux para que el engaño fuera visualmente perfecto en ambos.



Logging Estructurado: Capturar IPs, usuarios y contraseñas en tiempo real para su análisis.



💻 Stack Tecnológico:



Bash Scripting (Lógica y Sanitización de inputs)



Socat (Gestión de sockets y concurrencia)



Linux/Kali (Entorno de despliegue)



Este pequeño proyecto me ha ayudado a entender mejor cómo funcionan los handshakes de red y la importancia de no confiar en los inputs del usuario.

