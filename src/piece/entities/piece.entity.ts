import { Fabric } from "src/fabric/entities/fabric.entity";
import { Gabarit } from "src/gabarit/entities/gabarit.entity";
import { PrimaryGeneratedColumn, Column, DeleteDateColumn, Entity, OneToMany, ManyToOne, UpdateDateColumn, CreateDateColumn } from "typeorm";
@Entity()
export class Piece {
  @PrimaryGeneratedColumn()
  id: number;

  @ManyToOne(() => Gabarit, gabarit => gabarit.pieces, { onDelete: 'SET NULL' })
  gabarit: Gabarit;

  @ManyToOne(() => Fabric, fabric => fabric.pieces,{nullable:true, onDelete: 'SET NULL'})
  fabric: Fabric;

  @Column({ nullable: true })
  name?: string;

  @Column({ type: 'json' })
  boundingBox: {
    x: number;
    y: number;
    width: number;
    height: number;
  };

  @Column()
  precomputedArea: number;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @DeleteDateColumn()
  deletedAt?: Date;

}
