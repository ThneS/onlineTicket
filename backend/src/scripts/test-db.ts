import { PrismaClient } from '@prisma/client';

async function testDatabaseConnection() {
  const prisma = new PrismaClient();

  try {
    console.log('🔄 正在测试数据库连接...');

    // 测试连接
    await prisma.$connect();
    console.log('✅ 数据库连接成功');

    // 测试查询
    const result = await prisma.$queryRaw`SELECT version()` as any[];
    console.log('📊 PostgreSQL 版本:', result[0].version);

    // 测试表是否存在
    const tables = await prisma.$queryRaw`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public';
    ` as any[];
    console.log('📋 数据库表:', tables.map((t: any) => t.table_name).join(', '));

    console.log('🎉 数据库配置正确！');

  } catch (error: any) {
    console.error('❌ 数据库连接失败:');
    console.error('错误信息:', error.message);

    if (error.code === 'P1001') {
      console.log('\n🔧 解决方案:');
      console.log('1. 确认 PostgreSQL 服务正在运行');
      console.log('2. 检查 .env 文件中的 DATABASE_URL 配置');
      console.log('3. 确认数据库 "onlineticket" 已创建');
    } else if (error.code === 'P1003') {
      console.log('\n🔧 解决方案:');
      console.log('需要创建数据库: CREATE DATABASE onlineticket;');
    }

    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

// 如果直接运行此文件
if (require.main === module) {
  testDatabaseConnection();
}

export { testDatabaseConnection };
