import { Fabric } from "src/fabric/entities/fabric.entity";
import { Gabarit } from "src/gabarit/entities/gabarit.entity";
import { PrimaryGeneratedColumn, Column, DeleteDateColumn, Entity, ManyToOne, UpdateDateColumn, CreateDateColumn, OneToMany } from "typeorm";

@Entity()
export class Piece {
  @PrimaryGeneratedColumn()
  id: number;

  /** The template (gabarit) this piece comes from */
  @ManyToOne(() => Gabarit, gabarit => gabarit.pieces, { onDelete: 'SET NULL' })
  gabarit: Gabarit;

  /** The fabric chosen for this piece (optional) */
  @ManyToOne(() => Fabric, fabric => fabric.pieces, { nullable: true, onDelete: 'SET NULL' })
  fabric?: Fabric;

  /** Human-readable name: e.g. "Front Bodice", "Sleeve Left" */
  @Column({nullable:true})
  name: string;

  /** Outline of the piece as a polygon (instead of just bounding box) */
  @Column({ type: 'json' })
  outline: {
    points: { x: number; y: number }[]; // ordered list of points forming the polygon
  };

  // /** Precomputed bounding box for quick access */
  // @Column({ type: 'json' })
  // boundingBox: {
  //   x: number;
  //   y: number;
  //   width: number;
  //   height: number;
  // };

  /** Precomputed area of the polygon (not just bbox) */
  @Column('int')
  area: number;

  @Column({ nullable: true, default: 1 })
  NumberOfPieces : number;


  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @DeleteDateColumn()
  deletedAt?: Date;
}
