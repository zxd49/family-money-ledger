-- 在 Supabase SQL Editor 执行：创建记账表 money_ledger
CREATE TABLE IF NOT EXISTS money_ledger (
  id         bigint PRIMARY KEY,        -- 前端生成：毫秒时间戳+3位随机，无需自增
  type       text,                      -- 'expense' 支出 | 'income' 收入
  amount     numeric,
  category   text,
  note       text,
  date       text,                      -- YYYY-MM-DD
  created_at text
);

-- 演示用：放开匿名读写（正式使用建议在 Authentication → Policies 配置 RLS）
-- 如需匿名访问，可在 SQL Editor 执行：
-- CREATE POLICY "ledger_all" ON money_ledger FOR ALL USING (true) WITH CHECK (true);
