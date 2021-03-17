using Microsoft.Dynamics.TestTools.Dispatcher.Client;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using MS.Dynamics.Performance.Framework;
using MS.Dynamics.Performance.Framework.TaskRecorder;
using MS.Dynamics.TestTools.CloudCommonTestUtilities;
using MS.Dynamics.TestTools.CloudCommonTestUtilities.Enums;
using MS.Dynamics.TestTools.DispatcherProxyLibrary.ApplicationForms;
using MS.Dynamics.TestTools.UIHelpers.Core;
using System.Threading;

namespace MS.Dynamics.Performance.Application.SI.PDLTrend
{
    [TestClass]
    public sealed class ExpenseReportCreateAndSubmitBase
    {
        private RandomRange RandomNum = new RandomRange();
        private const int minThinkTime = 15000;
        private const int maxThinkTime = 35000;

        /// <summary>
        /// Simulate user's think time before taking actions.
        /// </summary>
        private void InsertThinkTime()
        {
            bool useThinkTime = DispatchedClientHelper.GetTestContextPropertyValue<bool>("UseThinkTime", this.TestContext, true);
            
            if (useThinkTime)
            {
                int sleepTime = RandomNum.GetNext(minThinkTime, maxThinkTime);
                Thread.Sleep(sleepTime);
            }
        }

        /// <summary>
        /// Gets the test context. Use the property for setting test transactions in the performance tests.
        /// </summary>
        public TestContext TestContext
        {
            get;
            set;
        }

        [TestCleanup]
        public void TestCleanup()
        {
            Client.Close();
            Client.Dispose();
            Client = null;
        }

        private DispatchedClient Client;
        private TimerProvider timerProvider;

        [TestInitialize]
        public void TestSetup()
        {
            bool useDetailedTimer = DispatchedClientHelper.GetTestContextPropertyValue<bool>("UseDetailedTimer", this.TestContext, true);
            
            if (useDetailedTimer && this.TestContext != null)
            {
                timerProvider = new TimerProvider(this.TestContext);
            }

            SetupData();
        }

        private void SetupClient()
        {
            DispatchedClientHelper helper = new DispatchedClientHelper();
                
            Client = helper.GetClient();
            Client.ForceEditMode = false;
            Client.Company = WellKnownCompanyID.USSI.ToString();
            Client.Open();
        }

        private ClientContext CreateClientContext()
        {
            if (timerProvider != null)
            {
                return ClientContext.Create(Client, timerProvider.OnBeginTimer, timerProvider.OnEndTimer);
            }
            return ClientContext.Create(Client);
        }

        private string ExpensePurpose;
        private string Category1;
        private string TrvExpenses_TrvExpTrans_AmountCurr;
        private string TrvExpenses_TrvExpTrans_TransDate;
        private string TrvExpenses_TrvExpTrans_AdditionalInformation;
        private string Category2;
        private string TrvExpenses_TrvExpTrans_AmountCurr1;
        private string TrvExpenses_TrvExpTrans_TransDate1;
        private string TrvExpenses_TrvExpTrans_AdditionalInformation1;
        private string TrvExpenses_TrvExpGuest_GuestId;
        private string TrvExpenses_TrvExpGuest_GuestId1;
        private int numberOfExpenseLines = 10;

        [TestMethod]
        public void ExpenseReportCreateAndSubmit()
        {
            SetupClient();            
            RunExpenseReportCreateAndSubmitTest();
        }

        /// <summary>
        /// Create an expense report. Add 10 lines and 10 guests in total and submit the report.
        /// </summary>
        private void RunExpenseReportCreateAndSubmitTest()
        {
            using (var c = this.CreateClientContext())
            {
                InsertThinkTime();
                
                using (var c1 = c.Navigate<TrvExpenseReportsList>("TrvExpRptListPage_MyListPage"))
                {
                    TrvExpenseReportsList TrvExpenseReportsListFormInstance = c1.Form<TrvExpenseReportsList>();
                    
                    InsertThinkTime();
                    
                    using (var c2 = c1.Action("CreateCommandButton_Click"))
                    {
                        Microsoft.Dynamics.TestTools.Dispatcher.Client.Controls.CommandButtonControl.Attach(TrvExpenseReportsListFormInstance, "CreateCommandButton").Click();
                        using (var c3 = c2.Attach<TrvExpenseReportDetails>())
                        {
                            TrvExpenseReportDetails TrvExpenseReportDetailsFormInstance = c3.Form<TrvExpenseReportDetails>();

                            TrvExpenseReportDetailsFormInstance.TrvExpTable_Txt2.ValueString = ExpensePurpose;
                            
                            using (var c6 = c3.Action("OkButton_Click"))
                            {
                                TrvExpenseReportDetailsFormInstance.OkButton.Click();
                                
                                using (var c7 = c6.Attach<TrvExpenses>())
                                {
                                    TrvExpenses TrvExpensesFormInstance = c7.Form<TrvExpenses>();
                                    
                                    for (int count = 0; count < numberOfExpenseLines; count = count + 2)
                                    {
                                        InsertThinkTime();
                                        
                                        TrvExpensesFormInstance.New();

                                        TrvExpensesFormInstance.TrvExpTrans_CostType.ValueString = Category1;

                                        TrvExpensesFormInstance.TrvExpTrans_AmountCurr.ValueString = TrvExpenses_TrvExpTrans_AmountCurr + count;
                                        TrvExpensesFormInstance.TrvExpTrans_TransDate.ValueString = TrvExpenses_TrvExpTrans_TransDate;
                                        TrvExpensesFormInstance.TrvExpTrans_AdditionalInformation.ValueString = TrvExpenses_TrvExpTrans_AdditionalInformation;
                                        Microsoft.Dynamics.TestTools.Dispatcher.Client.Controls.CommandButtonControl.Attach(TrvExpensesFormInstance, "SystemDefinedNewButton").Click();
                                        
                                        InsertThinkTime();
                                        
                                        TrvExpensesFormInstance.TrvExpTrans_CostType.ValueString = Category2;

                                        TrvExpensesFormInstance.TrvExpTrans_AmountCurr.ValueString = TrvExpenses_TrvExpTrans_AmountCurr1 + count + 1;
                                        TrvExpensesFormInstance.TrvExpTrans_TransDate.ValueString = TrvExpenses_TrvExpTrans_TransDate1;
                                        TrvExpensesFormInstance.TrvExpTrans_AdditionalInformation.ValueString = TrvExpenses_TrvExpTrans_AdditionalInformation1;

                                        TrvExpensesFormInstance.ExpenseLineGuestTabPage.Activate();
                                        
                                        InsertThinkTime();
                                        
                                        TrvExpensesFormInstance.AddGuest.Click();
                                        TrvExpensesFormInstance.TrvExpGuest_GuestId.ValueString = TrvExpenses_TrvExpGuest_GuestId;
                                        TrvExpensesFormInstance.AddGuest.Click();
                                        TrvExpensesFormInstance.TrvExpGuest_GuestId.ValueString = TrvExpenses_TrvExpGuest_GuestId1;

                                        Microsoft.Dynamics.TestTools.Dispatcher.Client.Controls.CommandButtonControl.Attach(TrvExpensesFormInstance, "SystemDefinedSaveButton").Click();
                                    }
                                }
                            }
                        }
                    }
                }

                InsertThinkTime();
                
                using (var c12 = c.Navigate<TrvExpenseReportsList>("TrvExpRptListPage_MyListPage"))
                {
                    TrvExpenseReportsList TrvExpenseReportsListFormInstance1 = c12.Form<TrvExpenseReportsList>();
                    Microsoft.Dynamics.TestTools.Dispatcher.Client.Controls.MenuButtonControl.Attach(TrvExpenseReportsListFormInstance1, "WorkflowActionBarButtonGroup").Click();
                    using (var c13 = c12.Action("WorkflowActionBarSubmitButton_Click"))
                    {
                        Microsoft.Dynamics.TestTools.Dispatcher.Client.Controls.MenuFunctionButtonControl.Attach(TrvExpenseReportsListFormInstance1, "WorkflowActionBarSubmitButton").Click();
                        using (var c14 = c13.Attach<WorkflowSubmitDialog>())
                        {
                            WorkflowSubmitDialog WorkflowSubmitDialogFormInstance = c14.Form<WorkflowSubmitDialog>();
                            WorkflowSubmitDialogFormInstance.Submit.Click();
                        }
                    }
                }
            }
        }

        private void SetupData()
        {
            ExpensePurpose = "Customer visit";
            Category1 = "Conference";
            TrvExpenses_TrvExpTrans_AmountCurr = "23.00";
            TrvExpenses_TrvExpTrans_TransDate = "2014-09-02";
            TrvExpenses_TrvExpTrans_AdditionalInformation = "Additional Information";
            Category2 = "Meal";
            TrvExpenses_TrvExpTrans_AmountCurr1 = "45.00";
            TrvExpenses_TrvExpTrans_TransDate1 = "2014-09-03";
            TrvExpenses_TrvExpTrans_AdditionalInformation1 = "Additional Information";
            TrvExpenses_TrvExpGuest_GuestId = "Guest1";
            TrvExpenses_TrvExpGuest_GuestId1 = "Guest2";
        }
    }
}
