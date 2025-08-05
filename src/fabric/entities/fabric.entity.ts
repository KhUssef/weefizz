import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  OneToMany,
} from 'typeorm';
import { User } from '../../user/entities/user.entity'; 
import { Piece } from 'src/piece/entities/piece.entity';

@Entity()
export class Fabric {
  @PrimaryGeneratedColumn('uuid')
  id: string;
  @Column()
  type: string;

  @Column()
  color: string;

  @Column('int')
  quantity: number;

  @Column()
  filePath: string;

  @ManyToOne(() => User, user => user.fabrics, { onDelete: 'CASCADE' })
  user: User;

  @OneToMany(() => Piece, piece => piece.fabric, { onDelete: 'SET NULL' })
  pieces: Piece[];

  @Column({default: false})
  favorited: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @DeleteDateColumn()
  deletedAt?: Date;
}
