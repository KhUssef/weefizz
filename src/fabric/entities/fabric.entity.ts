import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
} from 'typeorm';
import { User } from '../../user/entities/user.entity'; 

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

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @DeleteDateColumn()
  deletedAt?: Date;
}
