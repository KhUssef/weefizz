import { Fabric } from "src/fabric/entities/fabric.entity";
import { PrimaryGeneratedColumn, Column, DeleteDateColumn, Entity, OneToMany } from "typeorm";
@Entity()
export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({unique: true})
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

}
