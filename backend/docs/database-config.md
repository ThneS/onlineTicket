# PostgreSQL 数据库配置指南

## 📋 配置概述

后端项目使用 PostgreSQL 作为主数据库，通过 Prisma ORM 进行管理。数据库配置通过环境变量进行设置。

## 🔧 配置步骤

### 1. PostgreSQL 安装和启动

如果您使用 macOS，可以通过 Homebrew 安装：

```bash
# 安装 PostgreSQL
brew install postgresql

# 启动 PostgreSQL 服务
brew services start postgresql

# 创建用户和数据库
psql postgres
```

### 2. 数据库配置

在 PostgreSQL 中创建数据库和用户：

```sql
-- 连接到 PostgreSQL
psql postgres

-- 创建数据库
CREATE DATABASE onlineticket;

-- 创建用户（可选，如果不想使用默认用户）
CREATE USER ticketuser WITH PASSWORD 'yourpassword';

-- 授权
GRANT ALL PRIVILEGES ON DATABASE onlineticket TO ticketuser;

-- 退出
\q
```

### 3. 环境变量配置

在 `.env` 文件中配置数据库连接字符串：

#### 默认配置（推荐开发环境）

```properties
DATABASE_URL="postgresql://postgres:password@localhost:5432/onlineticket"
```

#### 自定义用户配置

```properties
DATABASE_URL="postgresql://ticketuser:yourpassword@localhost:5432/onlineticket"
```

#### 远程数据库配置

```properties
DATABASE_URL="postgresql://username:password@host:port/database"
```

### 4. 连接字符串格式说明

```
postgresql://[用户名]:[密码]@[主机]:[端口]/[数据库名]?[参数]
```

- **用户名**: PostgreSQL 用户名（默认: postgres）
- **密码**: 用户密码
- **主机**: 数据库服务器地址（本地: localhost）
- **端口**: PostgreSQL 端口（默认: 5432）
- **数据库名**: 目标数据库名称
- **参数**: 可选的连接参数

### 5. 连接参数示例

```properties
# 基本连接
DATABASE_URL="postgresql://postgres:password@localhost:5432/onlineticket"

# 带 SSL 连接
DATABASE_URL="postgresql://postgres:password@localhost:5432/onlineticket?sslmode=require"

# 连接池配置
DATABASE_URL="postgresql://postgres:password@localhost:5432/onlineticket?connection_limit=5"

# 指定模式
DATABASE_URL="postgresql://postgres:password@localhost:5432/onlineticket?schema=public"
```

## 🚀 数据库初始化

配置完成后，执行以下命令初始化数据库：

```bash
# 1. 生成 Prisma 客户端
npx prisma generate

# 2. 执行数据库迁移
npx prisma migrate dev --name init

# 3. 查看数据库状态
npx prisma migrate status

# 4. 初始化种子数据（可选）
npm run db:seed
```

## 🔍 常见配置问题

### 问题 1: 连接被拒绝

```
Error: P1001: Can't reach database server at `localhost:5432`
```

**解决方案:**

1. 确认 PostgreSQL 服务正在运行
2. 检查端口是否正确（默认 5432）
3. 验证防火墙设置

```bash
# 检查 PostgreSQL 状态
brew services list | grep postgresql

# 启动服务
brew services start postgresql

# 检查端口
lsof -i :5432
```

### 问题 2: 身份验证失败

```
Error: P1001: Authentication failed
```

**解决方案:**

1. 检查用户名和密码
2. 确认用户有访问数据库的权限
3. 检查 pg_hba.conf 配置

```sql
-- 重置密码
ALTER USER postgres PASSWORD 'newpassword';

-- 检查权限
\du
```

### 问题 3: 数据库不存在

```
Error: P1003: Database does not exist
```

**解决方案:**

```sql
-- 连接到 PostgreSQL
psql postgres

-- 创建数据库
CREATE DATABASE onlineticket;
```

### 问题 4: 编码问题

```
Error: P1002: The database server was reached but the database encoding is not supported
```

**解决方案:**

```sql
-- 创建数据库时指定编码
CREATE DATABASE onlineticket
WITH ENCODING 'UTF8'
LC_COLLATE='en_US.UTF-8'
LC_CTYPE='en_US.UTF-8';
```

## 🛠️ 高级配置

### 连接池配置

在 `src/services/database.ts` 中可以配置连接池：

```typescript
new PrismaClient({
  datasources: {
    db: {
      url: process.env.DATABASE_URL,
    },
  },
  log: ["query", "info", "warn", "error"],
});
```

### 环境特定配置

#### 开发环境 (.env.development)

```properties
DATABASE_URL="postgresql://postgres:password@localhost:5432/onlineticket_dev"
LOG_LEVEL="debug"
```

#### 测试环境 (.env.test)

```properties
DATABASE_URL="postgresql://postgres:password@localhost:5432/onlineticket_test"
LOG_LEVEL="error"
```

#### 生产环境 (.env.production)

```properties
DATABASE_URL="postgresql://user:password@prod-host:5432/onlineticket"
LOG_LEVEL="info"
```

## 📊 数据库监控

### 检查连接状态

```bash
# 使用 Prisma
npx prisma db pull

# 直接连接测试
psql "postgresql://postgres:password@localhost:5432/onlineticket" -c "SELECT version();"
```

### 性能监控

```sql
-- 查看活动连接
SELECT * FROM pg_stat_activity;

-- 查看数据库大小
SELECT pg_size_pretty(pg_database_size('onlineticket'));

-- 查看表信息
\dt
```

## 🔒 安全配置

### 生产环境安全建议

1. **使用专用用户**

```sql
CREATE USER app_user WITH PASSWORD 'strong_password';
GRANT CONNECT ON DATABASE onlineticket TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_user;
```

2. **限制连接权限**

```properties
# 限制连接数
DATABASE_URL="postgresql://app_user:password@localhost:5432/onlineticket?connection_limit=10"
```

3. **启用 SSL**

```properties
DATABASE_URL="postgresql://app_user:password@localhost:5432/onlineticket?sslmode=require"
```

## 🚦 快速测试

创建测试脚本验证数据库连接：

```bash
# 创建测试文件
cat > test-db.js << 'EOF'
const { PrismaClient } = require('@prisma/client');

async function testConnection() {
  const prisma = new PrismaClient();

  try {
    await prisma.$connect();
    console.log('✅ 数据库连接成功');

    const result = await prisma.$queryRaw`SELECT version()`;
    console.log('📊 数据库版本:', result[0].version);
  } catch (error) {
    console.error('❌ 数据库连接失败:', error.message);
  } finally {
    await prisma.$disconnect();
  }
}

testConnection();
EOF

# 运行测试
node test-db.js
```

## 📝 备份和恢复

### 数据备份

```bash
# 备份数据库
pg_dump onlineticket > backup.sql

# 备份到压缩文件
pg_dump onlineticket | gzip > backup.sql.gz
```

### 数据恢复

```bash
# 恢复数据库
psql onlineticket < backup.sql

# 从压缩文件恢复
gunzip -c backup.sql.gz | psql onlineticket
```

## 🔧 故障排除命令

```bash
# 重启 PostgreSQL
brew services restart postgresql

# 查看 PostgreSQL 日志
tail -f /opt/homebrew/var/log/postgresql@14.log

# 检查配置文件
psql postgres -c "SHOW config_file;"

# 查看所有数据库
psql postgres -c "\l"

# 查看用户权限
psql postgres -c "\du"
```
