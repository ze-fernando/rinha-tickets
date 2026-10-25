"""'init db'

Revision ID: c202307eb7a9
Revises:
Create Date: 2026-10-18 18:56:18.684720

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa



revision: str = 'c202307eb7a9'
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""

    op.create_table('tickets',
    sa.Column('title', sa.String(), nullable=False),
    sa.Column('description', sa.String(), nullable=False),
    sa.Column('sector', sa.String(), nullable=False),
    sa.Column('status', sa.Enum('OPEN', 'IN_PROGRESS', 'CLOSED', name='status'), nullable=False),
    sa.Column('finished_at', sa.DateTime(), nullable=True),
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('title')
    )



def downgrade() -> None:
    """Downgrade schema."""

    op.drop_table('tickets')

