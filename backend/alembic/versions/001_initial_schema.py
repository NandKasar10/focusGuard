"""initial schema for FocusGuard

Revision ID: 001_initial_schema
Revises: 
Create Date: 2026-10-30 18:30:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '001_initial_schema'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. users
    op.create_table(
        'users',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('email', sa.String(length=255), nullable=False),
        sa.Column('password_hash', sa.String(length=255), nullable=False),
        sa.Column('has_video', sa.Boolean(), nullable=False, server_default='0'),
        sa.Column('study_goals', sa.Text(), nullable=True),
        sa.Column('screenshot_consent', sa.Boolean(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)
    op.create_index(op.f('ix_users_id'), 'users', ['id'], unique=False)

    # 2. tracked_apps
    op.create_table(
        'tracked_apps',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('app_name', sa.String(length=100), nullable=False),
        sa.Column('package_or_process', sa.String(length=255), nullable=False),
        sa.Column('match_pattern', sa.String(length=255), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='1'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_tracked_apps_id'), 'tracked_apps', ['id'], unique=False)
    op.create_index(op.f('ix_tracked_apps_user_id'), 'tracked_apps', ['user_id'], unique=False)

    # 3. limits
    op.create_table(
        'limits',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('app_id', sa.Integer(), nullable=True),
        sa.Column('daily_limit_minutes', sa.Integer(), nullable=False, server_default='60'),
        sa.Column('continuous_session_limit_minutes', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['app_id'], ['tracked_apps.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_limits_id'), 'limits', ['id'], unique=False)
    op.create_index(op.f('ix_limits_user_id'), 'limits', ['user_id'], unique=False)
    op.create_index(op.f('ix_limits_app_id'), 'limits', ['app_id'], unique=False)

    # 4. usage_logs
    op.create_table(
        'usage_logs',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('app_id', sa.Integer(), nullable=False),
        sa.Column('date', sa.Date(), nullable=False),
        sa.Column('total_minutes', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('session_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('synced_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['app_id'], ['tracked_apps.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'app_id', 'date', name='uq_user_app_date')
    )
    op.create_index(op.f('ix_usage_logs_id'), 'usage_logs', ['id'], unique=False)
    op.create_index(op.f('ix_usage_logs_user_id'), 'usage_logs', ['user_id'], unique=False)
    op.create_index(op.f('ix_usage_logs_app_id'), 'usage_logs', ['app_id'], unique=False)
    op.create_index(op.f('ix_usage_logs_date'), 'usage_logs', ['date'], unique=False)

    # 5. suggestions
    op.create_table(
        'suggestions',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('app_name', sa.String(length=100), nullable=False),
        sa.Column('timestamp', sa.DateTime(), nullable=False),
        sa.Column('context_summary', sa.Text(), nullable=True),
        sa.Column('suggestion_text', sa.Text(), nullable=False),
        sa.Column('user_reply', sa.String(length=50), nullable=True),
        sa.Column('action_taken_after', sa.String(length=50), nullable=False, server_default='pending'),
        sa.Column('follow_up_time', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_suggestions_id'), 'suggestions', ['id'], unique=False)
    op.create_index(op.f('ix_suggestions_user_id'), 'suggestions', ['user_id'], unique=False)
    op.create_index(op.f('ix_suggestions_timestamp'), 'suggestions', ['timestamp'], unique=False)

    # 6. reminders
    op.create_table(
        'reminders',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('suggestion_id', sa.Integer(), nullable=True),
        sa.Column('scheduled_time', sa.DateTime(), nullable=False),
        sa.Column('message', sa.Text(), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='pending'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['suggestion_id'], ['suggestions.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_reminders_id'), 'reminders', ['id'], unique=False)
    op.create_index(op.f('ix_reminders_user_id'), 'reminders', ['user_id'], unique=False)
    op.create_index(op.f('ix_reminders_scheduled_time'), 'reminders', ['scheduled_time'], unique=False)


def downgrade() -> None:
    op.drop_table('reminders')
    op.drop_table('suggestions')
    op.drop_table('usage_logs')
    op.drop_table('limits')
    op.drop_table('tracked_apps')
    op.drop_table('users')
