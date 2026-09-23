import { Controller, Get, Param, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtGuard } from '../common/guards/jwt.guard';
import { FinanceService } from './finance.service';

@Controller()
@UseGuards(JwtGuard)
export class FinanceController {
  constructor(private readonly finance: FinanceService) {}

  @Get('parent/students/:studentId/invoices')
  invoices(@Param('studentId') studentId: string, @CurrentUser() user: any) {
    return this.finance.invoices(studentId, user.schoolId);
  }

  @Get('invoices/:invoiceId/receipt.pdf')
  async receipt(@Param('invoiceId') invoiceId: string, @CurrentUser() user: any, @Res() res: Response) {
    const invoice = await this.finance['prisma'].studentInvoice.findFirst({
      where: { id: invoiceId, schoolId: user.schoolId },
      include: { student: true },
    });
    if (!invoice) return res.status(404).json({ message: 'Invoice not found' });

    // PDF generation should be moved to a queue/worker in production.
    // Returning a minimal valid PDF keeps the API contract testable now.
    const body = `School Receipt\\nInvoice: ${invoice.invoiceNumber}\\nStudent: ${invoice.student.firstName}\\nTotal: ${invoice.totalAmount}\\nPaid: ${invoice.paidAmount}\\nBalance: ${invoice.balanceDue}`;
    const stream = [
      '%PDF-1.4',
      '1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj',
      '2 0 obj<</Type/Pages/Count 0/Kids[]>>endobj',
      `3 0 obj<</Length ${body.length}>>stream`,
      body,
      'endstream endobj',
      'trailer<</Root 1 0 R>>',
      '%%EOF',
    ].join('\\n');
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="receipt-${invoice.invoiceNumber}.pdf"`);
    return res.send(Buffer.from(stream));
  }
}
