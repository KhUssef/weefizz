import { Fabric } from "src/fabric/entities/fabric.entity";
import { Gabarit } from "src/gabarit/entities/gabarit.entity";
import { PrimaryGeneratedColumn, Column, DeleteDateColumn, Entity, OneToMany } from "typeorm";
@Entity()
export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({})
  username: string;

  @Column({unique: true})
  email: string;

  @Column()
  password: string;

  @DeleteDateColumn()
  deletedAt?: Date;

  @Column({ default: false }) 
  isEmailVerified: boolean;

  @OneToMany(() => Fabric, fabric => fabric.user)
  fabrics?: Fabric[];
  
  @OneToMany(() => Gabarit, gabarit => gabarit.user)
  gabarits?: Gabarit[];

}
