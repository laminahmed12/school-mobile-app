import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma.service';

@Injectable()
export class FinanceService {
  constructor(private readonly prisma: PrismaService) {}

  async invoices(studentId: string, schoolId: string) {
    const rows = await this.prisma.studentInvoice.findMany({
      where: { studentId, schoolId },
      orderBy: { issueDate: 'desc' },
    });

    return {
      items: rows.map(x => ({
        id: x.id,
        invoice_number: x.invoiceNumber,
        total_amount: Number(x.totalAmount),
        paid_amount: Number(x.paidAmount),
        balance_due: Number(x.balanceDue),
        status: x.status,
      })),
    };
  }
}
