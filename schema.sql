-- ===================================================
-- かけいぼ アプリ データベーススキーマ
-- Supabase (PostgreSQL) 用
-- Phase 1 — 2026-04-17
-- ===================================================

-- ===== Extensions =====
create extension if not exists "uuid-ossp";

-- ===== user_profiles =====
-- Supabase Auth の users テーブルに紐づくプロフィール
create table if not exists public.user_profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text,
  theme_color   text default 'teal',
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- RLS
alter table public.user_profiles enable row level security;

create policy "自分のプロフィールのみ参照" on public.user_profiles
  for select using (auth.uid() = id);

create policy "自分のプロフィールのみ更新" on public.user_profiles
  for update using (auth.uid() = id);

create policy "プロフィール作成" on public.user_profiles
  for insert with check (auth.uid() = id);

-- ===== fixed_income（固定収入）=====
create table if not exists public.fixed_income (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,             -- 例: 給料、年金
  category    text,                      -- カテゴリ
  amount      integer not null default 0, -- 金額（円）
  is_active   boolean not null default true,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

alter table public.fixed_income enable row level security;

create policy "自分の固定収入のみ操作" on public.fixed_income
  for all using (auth.uid() = user_id);

-- ===== fixed_expense（固定支出）=====
create table if not exists public.fixed_expense (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,             -- 例: 家賃、電気代
  category    text,                      -- カテゴリ
  amount      integer not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

alter table public.fixed_expense enable row level security;

create policy "自分の固定支出のみ操作" on public.fixed_expense
  for all using (auth.uid() = user_id);

-- ===== daily_expense（日別支出）=====
create table if not exists public.daily_expense (
  id             uuid primary key default uuid_generate_v4(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  date           date not null default current_date,
  amount         integer not null,        -- 支出金額（円）
  category       text,                    -- カテゴリ（食費、外食、交通 等）
  store          text,                    -- 購入場所・店名
  payment_method text,                   -- 支払い方法（現金/カード/PayPay 等）
  memo           text,                   -- メモ
  ocr_image_url  text,                   -- OCR用画像URL（Phase 2）
  created_at     timestamptz default now()
);

alter table public.daily_expense enable row level security;

create policy "自分の日別支出のみ操作" on public.daily_expense
  for all using (auth.uid() = user_id);

-- Index for date range queries
create index if not exists daily_expense_user_date_idx
  on public.daily_expense(user_id, date desc);

-- ===== credit_cards（クレジットカード）=====
create table if not exists public.credit_cards (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  card_name     text not null,           -- カード名
  credit_limit  integer not null default 0, -- 利用限度額（円）
  billing_date  integer,                 -- 締め日（1〜31）
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

alter table public.credit_cards enable row level security;

create policy "自分のカードのみ操作" on public.credit_cards
  for all using (auth.uid() = user_id);

-- ===== credit_transactions（クレジット利用履歴）=====
create table if not exists public.credit_transactions (
  id          uuid primary key default uuid_generate_v4(),
  card_id     uuid not null references public.credit_cards(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  date        date not null default current_date,
  amount      integer not null,
  description text,
  created_at  timestamptz default now()
);

alter table public.credit_transactions enable row level security;

create policy "自分のカード利用のみ操作" on public.credit_transactions
  for all using (auth.uid() = user_id);

create index if not exists credit_transactions_card_date_idx
  on public.credit_transactions(card_id, date desc);

-- ===== debts（借入・返済管理）=====
create table if not exists public.debts (
  id               uuid primary key default uuid_generate_v4(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  creditor_name    text not null,         -- 借入先名
  total_amount     integer not null,      -- 借入総額（円）
  remaining        integer not null,      -- 残高（円）
  monthly_payment  integer,              -- 月々の返済額
  interest_rate    numeric(5,2),         -- 金利（%）
  due_date         date,                 -- 返済期限
  is_completed     boolean default false,
  created_at       timestamptz default now(),
  updated_at       timestamptz default now()
);

alter table public.debts enable row level security;

create policy "自分の借入のみ操作" on public.debts
  for all using (auth.uid() = user_id);

-- ===== debt_payments（返済履歴）=====
create table if not exists public.debt_payments (
  id        uuid primary key default uuid_generate_v4(),
  debt_id   uuid not null references public.debts(id) on delete cascade,
  user_id   uuid not null references auth.users(id) on delete cascade,
  date      date not null default current_date,
  amount    integer not null,
  memo      text,
  created_at timestamptz default now()
);

alter table public.debt_payments enable row level security;

create policy "自分の返済履歴のみ操作" on public.debt_payments
  for all using (auth.uid() = user_id);

-- ===== ai_reports（AI振り返りレポート）Phase 2 =====
create table if not exists public.ai_reports (
  id             uuid primary key default uuid_generate_v4(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  month          text not null,           -- 例: '2026-04'
  report_content text,
  created_at     timestamptz default now()
);

alter table public.ai_reports enable row level security;

create policy "自分のAIレポートのみ操作" on public.ai_reports
  for all using (auth.uid() = user_id);

-- ===================================================
-- トリガー: updated_at 自動更新
-- ===================================================
create or replace function public.update_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_user_profiles_updated_at
  before update on public.user_profiles
  for each row execute function public.update_updated_at();

create trigger trg_fixed_income_updated_at
  before update on public.fixed_income
  for each row execute function public.update_updated_at();

create trigger trg_fixed_expense_updated_at
  before update on public.fixed_expense
  for each row execute function public.update_updated_at();

create trigger trg_credit_cards_updated_at
  before update on public.credit_cards
  for each row execute function public.update_updated_at();

create trigger trg_debts_updated_at
  before update on public.debts
  for each row execute function public.update_updated_at();

-- ===================================================
-- サンプルデータ（オプション — 開発用）
-- ===================================================
-- INSERT INTO public.fixed_income (user_id, name, category, amount)
--   VALUES ('YOUR_USER_ID', '給料', '収入', 250000);
-- INSERT INTO public.fixed_expense (user_id, name, category, amount)
--   VALUES ('YOUR_USER_ID', '家賃', '住居', 80000);
