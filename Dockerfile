FROM node:22-alpine AS base

# 1. Instalar dependencias solo cuando sea necesario
FROM base AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Copiar archivos de dependencias
COPY package.json package-lock.json* yarn.lock* ./

# Instalar dependencias (usar ci para npm o frozen-lockfile para yarn)
RUN  npm install;

# 2. Reconstruir el código fuente
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# ACEPTAR LA VARIABLE DE ENTORNO EN TIEMPO DE CONSTRUCCIÓN
ARG NEXT_PUBLIC_AUTH_URL
ENV NEXT_PUBLIC_AUTH_URL=${NEXT_PUBLIC_AUTH_URL}

# Deshabilitar telemetría durante el build
ENV NEXT_TELEMETRY_DISABLED 1

RUN npm run build;

# 3. Imagen de Producción, copiar todos los archivos y ejecutar next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Configurar permisos correctos para caché de prerenderizado
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Copiar automáticamente la carpeta standalone y la carpeta static
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000
# set hostname to localhost
ENV HOSTNAME "0.0.0.0"

CMD ["node", "server.js"]
