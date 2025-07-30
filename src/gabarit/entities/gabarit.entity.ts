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
export class Gabarit {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column()
  filePath: string; 

  @ManyToOne(() => User, user => user.gabarits, { onDelete: 'CASCADE', nullable: false })
  user: User;

  @OneToMany(() => Piece, piece => piece.gabarit, {onDelete: 'CASCADE'})
  pieces: Piece[];

  @CreateDateColumn()
  createdAt: Date;

  @Column({ nullable: true, comment: 'scale used for picture to real life resizeing : 1 pixel in the picture corresponds to X cm in real life', default: 1 })
  scale: number;

  @UpdateDateColumn()
  updatedAt: Date;

  @DeleteDateColumn()
  deletedAt?: Date; 
}
